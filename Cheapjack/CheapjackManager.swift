//
//  CheapjackManager.swift
//  TBDropbox
//
//  Created by Tim Bueno on 2015-08-04.
//  Copyright © 2015 Tim Bueno. All rights reserved.
//

import Foundation


public protocol CheapjackDelegate: class {
    func cheapjackManager(_ manager: CheapjackManager, didChangeState from: State, to: State, forFile file: CheapjackFile)
    func cheapjackManager(_ manager: CheapjackManager, didUpdateProgress progress: Double, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64, forFile file: CheapjackFile)
    func cheapjackManager(_ manager: CheapjackManager, didReceiveError error: NSError?)
    func cheapjackManager(_ manager: CheapjackManager, didFinishDownloading withSession: URLSession, downloadTask: URLSessionDownloadTask, url: URL, forFile file: CheapjackFile)
}


struct SessionProperties {
    static let backgroundSessionIdentifier = "com.gurpartap.Cheapjack"
}


open class CheapjackManager: NSObject {
    
    public typealias DidFinishDownloadingBlock = (_ session: Foundation.URLSession, _ downloadTask: URLSessionDownloadTask, _ url: URL, _ file: CheapjackFile) -> (Void)
    
    open weak var delegate: CheapjackDelegate?
    
    open var deleteFileAfterComplete = false
    
    open var didFinishDownloadingBlock: CheapjackManager.DidFinishDownloadingBlock?
    
    open var files: Dictionary<CheapjackFile.Identifier, CheapjackFile>
    var backgroundSession: Foundation.URLSession!
    
    open static let sharedManager = CheapjackManager()
    
    @objc dynamic open var numberOfPendingDownloads:Int = 0

    override init() {
        files = Dictionary<CheapjackFile.Identifier, CheapjackFile>()
        
        super.init()
        
        let backgroundSessionConfiguration = URLSessionConfiguration.background(withIdentifier: SessionProperties.backgroundSessionIdentifier)
        backgroundSession = Foundation.URLSession(configuration: backgroundSessionConfiguration, delegate: self, delegateQueue: nil)
    }
    
    // Helper method for starting a download for a new CheapjackFile instance.
    open func download(_ url: URL,fileName: String? = nil,directoryName: String? = nil, identifier: CheapjackFile.Identifier, userInfo: Dictionary<String, AnyObject>? = nil, delegate: CheapjackFileDelegate? = nil, didChangeStateBlock: CheapjackFile.Listener.DidChangeStateBlock? = nil, didUpdateProgressBlock: CheapjackFile.Listener.DidUpdateProgressBlock? = nil) {
        let request = URLRequest(url: url)
        download(request,fileName: fileName,directoryName:directoryName, identifier: identifier, userInfo: userInfo, delegate: delegate, didChangeStateBlock: didChangeStateBlock, didUpdateProgressBlock: didUpdateProgressBlock)
    }
    
    open func download(_ request: URLRequest,fileName: String? = nil,directoryName: String? = nil,identifier: CheapjackFile.Identifier, userInfo: Dictionary<String, AnyObject>? = nil, delegate: CheapjackFileDelegate? = nil, didChangeStateBlock: CheapjackFile.Listener.DidChangeStateBlock? = nil, didUpdateProgressBlock: CheapjackFile.Listener.DidUpdateProgressBlock? = nil) {
        let listener = CheapjackFile.Listener(delegate: delegate, didChangeStateBlock: didChangeStateBlock, didUpdateProgressBlock: didUpdateProgressBlock)
        let file = CheapjackFile(identifier: identifier, request: request, listeners: [listener],fileName: fileName ,
                                 directoryName: directoryName)
        if let ui = userInfo {
            file.userInfo = ui
        }
        resume(file)

    }
    
    open func pendingDownloads() -> Int {
        return self.files.filter({ (identifier, file) in
            return file.state != .finished && file.state != .cancelled
        }).count
    }
}


// MARK: - Action on file with identifier

extension CheapjackManager {
    
    public func resume(_ identifier: CheapjackFile.Identifier) -> Bool {
        if let file = files[identifier] {
            resume(file)
            return true
        }
        return false
    }
    
    public func pause(_ identifier: CheapjackFile.Identifier) -> Bool {
        if let file = files[identifier] {
            pause(file)
            return true
        }
        return false
    }
    
    public func cancel(_ identifier: CheapjackFile.Identifier) -> Bool {
        if let file = files[identifier] {
            cancel(file)
            return true
        }
        return false
    }
    
}


// MARK: - Action on CheapjackFile

extension CheapjackManager {
    
    public func resume(_ file: CheapjackFile) {
        file.manager = self
        files[file.identifier] = file
        
        switch file.state {
        case .paused(let data):
            file.setState(.waiting)
            file.downloadTask = backgroundSession.downloadTask(withResumeData: data)
        default:
            file.setState(.waiting)
            if file.request == nil {
                file.request = URLRequest(url: file.url!)
            }
            file.downloadTask = backgroundSession.downloadTask(with: file.request!)
        }
        file.downloadTask?.taskDescription = file.identifier
        file.downloadTask?.resume()
        numberOfPendingDownloads = pendingDownloads()
    }
    
    public func pause(_ file: CheapjackFile) {
        file.downloadTask?.cancel(byProducingResumeData: { resumeDataOrNil in
            if let data = resumeDataOrNil {
                file.setState(.paused(data))
                //save download item
                self.storeDownloadItem(file: file)
                print("paused")
            } else {
                file.setState(.cancelled)
                // TODO: Handle server not supporting resumes.
                print("can't resume this later. cancelling instead.")
            }
        })
    }
    
    public func cancel(_ file: CheapjackFile) {
        file.setState(.cancelled)
        file.downloadTask?.cancel()
    }
    
}


// MARK: - Action on all

extension CheapjackManager {
    
    public func resumeAll() {
        guard let files = restoredDownloadItems() else {
            return
        }
        for file in files.values {
            resume(file)
        }
    }
    
    public func pauseAll() {
        for file in files.values {
            pause(file)
        }
        storeDownloadItems()
    }
    
    public func cancelAll() {
        for file in files.values {
            cancel(file)
        }
    }
    
    func storeDownloadItem(file:CheapjackFile) {
        try? UserDefaults.standard.set(PropertyListEncoder().encode(file), forKey: file.identifier)
        
    }
    func restoredDownloadItem(identifier:CheapjackFile.Identifier) -> CheapjackFile? {
        
        guard let encoded = UserDefaults.standard.object(forKey: identifier) as? Data else{
            return nil
        }
        let file = try! PropertyListDecoder().decode(CheapjackFile.self, from: encoded)
        return file
    }
    
    func storeDownloadItems() {
        //save the identifiers of files
        try? UserDefaults.standard.set(PropertyListEncoder().encode(Array(files.keys)), forKey: "downloadItemKeys")
    }
    
    func restoredDownloadItems() -> [CheapjackFile.Identifier:CheapjackFile]? {
        
        guard let encoded = UserDefaults.standard.object(forKey: "downloadItemKeys") as? Data else{
            return nil
        }
        
        let  filesKeys:[CheapjackFile.Identifier] = try! PropertyListDecoder().decode([CheapjackFile.Identifier].self, from: encoded)
        
        var savedFiles:[CheapjackFile.Identifier:CheapjackFile] = [CheapjackFile.Identifier:CheapjackFile]()
        
        for key in filesKeys {
            if let encoded = UserDefaults.standard.object(forKey: key) as? Data,let file = try? PropertyListDecoder().decode(CheapjackFile.self, from: encoded){
                savedFiles[key] = file
            }
        }
        return savedFiles
    }
    
}


extension CheapjackManager {
    public func remove(_ identifier: CheapjackFile.Identifier) {
        cancel(identifier)
        UserDefaults.standard.removeObject(forKey: identifier)
        files.removeValue(forKey: identifier)
        numberOfPendingDownloads = pendingDownloads()
    }
    
    public func remove(_ filesWithState: State) {
        var filesCopy = files
        for (identifier, file) in filesCopy {
            if file.state != filesWithState {
                filesCopy.removeValue(forKey: identifier)
            }
        }
        files = filesCopy
    }
    
}


extension CheapjackManager: URLSessionDownloadDelegate {
    
    
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        if let file = files[downloadTask.taskDescription!] {
            file.setState(.finished)
            move(cheapjackFile: file, location: location)
            delegate?.cheapjackManager(self, didFinishDownloading: session, downloadTask: downloadTask, url: location, forFile: file)
            if let didFinishDownloadingBlock = didFinishDownloadingBlock {
                didFinishDownloadingBlock(session, downloadTask, location, file)
            }
            
            if deleteFileAfterComplete {
                files.removeValue(forKey: downloadTask.taskDescription!)
                numberOfPendingDownloads = pendingDownloads()
            }
            
        }
    }
    
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        if let file = files[downloadTask.taskDescription!] {
            if file.state != State.downloading {
                file.setState(.downloading)
            }
            
            file.setTotalBytesWritten(totalBytesWritten)
            file.setTotalBytesExpectedToWrite(totalBytesExpectedToWrite)
        }
    }
    
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didResumeAtOffset fileOffset: Int64, expectedTotalBytes: Int64) {
        print("didResumeAtOffset")
    }
    
}


extension CheapjackManager: URLSessionTaskDelegate {
    
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            print(error)
            delegate?.cheapjackManager(self, didReceiveError: error as NSError?)
        }
    }
    
    public func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        if let error = error {
            print(error)
            delegate?.cheapjackManager(self, didReceiveError: error as NSError?)
        }
    }
    
    public func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        session.getTasksWithCompletionHandler { dataTasks, uploadTasks, downloadTasks in
            if downloadTasks.count == 0 {
                
            }
        }
    }
    
}

extension CheapjackManager {
    static func docmentDirectoryPath () -> URL {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    func move(cheapjackFile:CheapjackFile,location:URL) {
        let directory = CheapjackManager.docmentDirectoryPath()
        let path = directory.appendingPathComponent(cheapjackFile.directoryName!)
        do {
            if (!FileManager.default.fileExists(atPath: path.absoluteString)) {
                try FileManager.default.createDirectory(at: path, withIntermediateDirectories: true, attributes: nil)
            }
            
            let destinationLocation = path.appendingPathComponent(cheapjackFile.fileName!)
            
            if FileManager.default.fileExists(atPath: destinationLocation.path) {
                try! FileManager.default.removeItem(at: destinationLocation)
            }
            
            try FileManager.default.moveItem(at: location, to: destinationLocation)
            
        } catch {
            print("Error while moving file! \(    print(error.localizedDescription))")
        }
    }
    
}

