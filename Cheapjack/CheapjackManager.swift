//
//  CheapjackManager.swift
//  TBDropbox
//
//  Created by Tim Bueno on 2015-08-04.
//  Copyright © 2015 Tim Bueno. All rights reserved.
//

import Foundation


public protocol CheapjackDelegate: class {
    func cheapjackManager(manager: CheapjackManager, didChangeState from: CheapjackFile.State, to: CheapjackFile.State, forFile file: CheapjackFile)
    func cheapjackManager(manager: CheapjackManager, didUpdateProgress progress: Double, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64, forFile file: CheapjackFile)
    func cheapjackManager(manager: CheapjackManager, didReceiveError error: NSError?)
    func cheapjackManager(manager: CheapjackManager, didFinishDownloading withSession: NSURLSession, downloadTask: NSURLSessionDownloadTask, url: NSURL, forFile file: CheapjackFile)
}


struct SessionProperties {
    static let backgroundSessionIdentifier = "com.gurpartap.Cheapjack"
}


public class CheapjackManager: NSObject {
    
    public typealias DidFinishDownloadingBlock = (session: NSURLSession, downloadTask: NSURLSessionDownloadTask, url: NSURL, file: CheapjackFile) -> (Void)
    
    public weak var delegate: CheapjackDelegate?
    
    public var deleteFileAfterComplete = false
    
    public var didFinishDownloadingBlock: CheapjackManager.DidFinishDownloadingBlock?
    
    public var files: Dictionary<CheapjackFile.Identifier, CheapjackFile>
    var backgroundSession: NSURLSession!
    
    public static let sharedManager = CheapjackManager()
    
    
    override init() {
        files = Dictionary<CheapjackFile.Identifier, CheapjackFile>()
        
        super.init()
        
        let backgroundSessionConfiguration = NSURLSessionConfiguration.backgroundSessionConfigurationWithIdentifier(SessionProperties.backgroundSessionIdentifier)
        backgroundSession = NSURLSession(configuration: backgroundSessionConfiguration, delegate: self, delegateQueue: nil)
    }
    
    // Helper method for starting a download for a new CheapjackFile instance.
    public func download(url: NSURL, identifier: CheapjackFile.Identifier, delegate: CheapjackFileDelegate? = nil, didChangeStateBlock: CheapjackFile.Listener.DidChangeStateBlock? = nil, didUpdateProgressBlock: CheapjackFile.Listener.DidUpdateProgressBlock? = nil) {
        let listener = CheapjackFile.Listener(delegate: delegate, didChangeStateBlock: didChangeStateBlock, didUpdateProgressBlock: didUpdateProgressBlock)
        let file = CheapjackFile(identifier: identifier, url: url, listeners: [listener])
        resume(file)
    }
    
    public func pendingDownloads() -> Int {
        return self.files.filter({ (identifier, file) in
            return file.state != .Finished && file.state != .Cancelled
        }).count
    }
    
}


// MARK: - Action on file with identifier

extension CheapjackManager {
    
    public func resume(identifier: CheapjackFile.Identifier) -> Bool {
        if let file = files[identifier] {
            resume(file)
            return true
        }
        return false
    }
    
    public func pause(identifier: CheapjackFile.Identifier) -> Bool {
        if let file = files[identifier] {
            pause(file)
            return true
        }
        return false
    }
    
    public func cancel(identifier: CheapjackFile.Identifier) -> Bool {
        if let file = files[identifier] {
            cancel(file)
            return true
        }
        return false
    }
    
}


// MARK: - Action on CheapjackFile

extension CheapjackManager {
    
    public func resume(file: CheapjackFile) {
        file.manager = self
        files[file.identifier] = file
        
        
        switch file.state {
        case .Paused(let data):
            file.setState(.Waiting)
            file.downloadTask = backgroundSession.downloadTaskWithResumeData(data)
        default:
            file.setState(.Waiting)
            file.downloadTask = backgroundSession.downloadTaskWithURL(file.url)
        }
        file.downloadTask?.taskDescription = file.identifier
        file.downloadTask?.resume()
    }
    
    public func pause(file: CheapjackFile) {
        file.downloadTask?.cancelByProducingResumeData({ resumeDataOrNil in
            if let data = resumeDataOrNil {
                file.setState(.Paused(data))
                print("paused")
            } else {
                file.setState(.Cancelled)
                // TODO: Handle server not supporting resumes.
                print("can't resume this later. cancelling instead.")
            }
        })
    }
    
    public func cancel(file: CheapjackFile) {
        file.setState(.Cancelled)
        file.downloadTask?.cancel()
    }
    
}


// MARK: - Action on all

extension CheapjackManager {
    
    public func resumeAll() {
        for file in files.values {
            resume(file)
        }
    }
    
    public func pauseAll() {
        for file in files.values {
            pause(file)
        }
    }
    
    public func cancelAll() {
        for file in files.values {
            cancel(file)
        }
    }
    
}


extension CheapjackManager {
    public func remove(identifier: CheapjackFile.Identifier) {
        files.removeValueForKey(identifier)
    }
    
    public func remove(filesWithState: CheapjackFile.State) {
        var filesCopy = files
        for (identifier, file) in filesCopy {
            if file.state != filesWithState {
                filesCopy.removeValueForKey(identifier)
            }
        }
        files = filesCopy
    }
}


extension CheapjackManager: NSURLSessionDownloadDelegate {
    
    public func URLSession(session: NSURLSession, downloadTask: NSURLSessionDownloadTask, didFinishDownloadingToURL location: NSURL) {
        if let file = files[downloadTask.taskDescription!] {
            file.setState(.Finished)
            delegate?.cheapjackManager(self, didFinishDownloading: session, downloadTask: downloadTask, url: location, forFile: file)
            if let didFinishDownloadingBlock = didFinishDownloadingBlock {
                didFinishDownloadingBlock(session: session, downloadTask: downloadTask, url: location, file: file)
            }
            
            if deleteFileAfterComplete {
                files.removeValueForKey(downloadTask.taskDescription!)
            }
            
        }
    }
    
    public func URLSession(session: NSURLSession, downloadTask: NSURLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        if let file = files[downloadTask.taskDescription!] {
            if file.state != CheapjackFile.State.Downloading {
                file.setState(.Downloading)
            }
            
            file.setTotalBytesWritten(totalBytesWritten)
            file.setTotalBytesExpectedToWrite(totalBytesExpectedToWrite)
        }
    }
    
    public func URLSession(session: NSURLSession, downloadTask: NSURLSessionDownloadTask, didResumeAtOffset fileOffset: Int64, expectedTotalBytes: Int64) {
        print("didResumeAtOffset")
    }
    
}


extension CheapjackManager: NSURLSessionDelegate {
    
    public func URLSession(session: NSURLSession, task: NSURLSessionTask, didCompleteWithError error: NSError?) {
        if let error = error {
            print(error)
            delegate?.cheapjackManager(self, didReceiveError: error)
        }
    }
    
    public func URLSession(session: NSURLSession, didBecomeInvalidWithError error: NSError?) {
        if let error = error {
            print(error)
            delegate?.cheapjackManager(self, didReceiveError: error)
        }
    }
    
    public func URLSessionDidFinishEventsForBackgroundURLSession(session: NSURLSession) {
        session.getTasksWithCompletionHandler { dataTasks, uploadTasks, downloadTasks in
            if downloadTasks.count == 0 {
                
            }
        }
    }
    
}
