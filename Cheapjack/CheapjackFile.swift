//
//  CheapjackFile.swift
//  TBDropbox
//
//  Created by Tim Bueno on 2015-08-04.
//  Copyright © 2015 Tim Bueno. All rights reserved.
//

import Foundation


public protocol CheapjackFileDelegate: class {
    var identifier: Int { get}
    func cheapjackFile(_ file: CheapjackFile, didChangeState from: State, to: State)
    func cheapjackFile(_ file: CheapjackFile, didUpdateProgress progress: Double, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64)
}


public func ==(lhs: CheapjackFile, rhs: CheapjackFile) -> Bool {
    return lhs.identifier == rhs.identifier
}


extension State: Equatable {
}

public func ==(lhs: State, rhs: State) -> Bool {
    switch (lhs, rhs) {
    case (let .paused(data1), let .paused(data2)):
        return data1 == data2
    case (.unknown, .unknown):
        return true
    case (.waiting, .waiting):
        return true
    case (.downloading, .downloading):
        return true
    case (.finished, .finished):
        return true
    case (.cancelled, .cancelled):
        return true
    case (.failed, .failed):
        return true
    default:
        return false
    }
}



open class CheapjackFile:Equatable,Codable {
    
    // A listener may implement either of delegate and blocks.
    open class Listener {
        
        public typealias DidChangeStateBlock = (_ from: State, _ to: State) -> (Void)
        public typealias DidUpdateProgressBlock = (_ progress: Double, _ totalBytesWritten: Int64, _ totalBytesExpectedToWrite: Int64) -> (Void)
        
        
        open weak var delegate: CheapjackFileDelegate?
        open var didChangeStateBlock: CheapjackFile.Listener.DidChangeStateBlock?
        open var didUpdateProgressBlock: CheapjackFile.Listener.DidUpdateProgressBlock?
        
        public init(delegate: CheapjackFileDelegate? = nil, didChangeStateBlock: CheapjackFile.Listener.DidChangeStateBlock? = nil, didUpdateProgressBlock: CheapjackFile.Listener.DidUpdateProgressBlock? = nil) {
            self.delegate = delegate
            self.didChangeStateBlock = didChangeStateBlock
            self.didUpdateProgressBlock = didUpdateProgressBlock
        }
        
    }
    private enum CodingKeys: String, CodingKey {
        case identifier ,url,state,lastState,totalBytesWritten,totalBytesExpectedToWrite,fileName,directoryName
        
    }
    
    required public init(from decoder: Decoder) throws
    {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        identifier = try values.decode(String.self, forKey: .identifier)
        url = try values.decode(URL.self, forKey: .url)
        state = try values.decode(State.self, forKey: .state)
        lastState = try values.decode(State.self, forKey: .lastState)
        totalBytesWritten = try values.decode(Int64.self, forKey: .totalBytesWritten)
        totalBytesExpectedToWrite = try values.decode(Int64.self, forKey: .totalBytesExpectedToWrite)
        fileName = try values.decode(String.self, forKey: .fileName)
        directoryName = try values.decode(String.self, forKey: .directoryName)
        
    }
    
    public func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(identifier, forKey: .identifier)
        try container.encode(url, forKey: .url)
        try container.encode(state, forKey: .state)
        try container.encode(lastState, forKey: .lastState)
        try container.encode(totalBytesWritten, forKey: .totalBytesWritten)
        try container.encode(totalBytesExpectedToWrite, forKey: .totalBytesExpectedToWrite)
        try container.encode(fileName, forKey: .fileName)
        try container.encode(directoryName, forKey: .directoryName)
    }
    
    public typealias Identifier = String
    
    
    // MARK: - CheapjackFile public properties
    
    internal weak var manager: CheapjackManager? = nil
    open var identifier: CheapjackFile.Identifier = ""
    open var url: URL? = nil
    open var request: URLRequest? = nil
    open var fileName : String? = nil
    open var directoryName : String? = nil
    
    open var progress: Double {
        if totalBytesExpectedToWrite > 0 {
            return Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        } else {
            return 0.0
        }
    }
    
    open var userInfo = Dictionary<String, AnyObject>()
    
    // MARK: - CheapjackFile public read-only properties
    
    open fileprivate(set) var lastState: State = .unknown
    open fileprivate(set) var state: State {
        willSet {
            lastState = state
        }
        didSet {
            notifyChangeStateListeners()
        }
    }
    open fileprivate(set) var totalBytesExpectedToWrite: Int64 = 0
    open fileprivate(set) var totalBytesWritten: Int64 {
        didSet {
            notifyUpdateProgressListeners()
        }
    }
    
    // MARK: - CheapjackFile private properties
    
    open var listeners: [CheapjackFile.Listener]  = [CheapjackFile.Listener]()
    internal var downloadTask: URLSessionDownloadTask? = nil
    
    
    // MARK: - Initializers
    
    public init(identifier: CheapjackFile.Identifier, request: URLRequest, listeners: [CheapjackFile.Listener]? = nil,fileName: String? = nil ,
                directoryName: String? = nil ) {
        self.identifier = identifier
        self.url = request.url!
        self.request = request
        self.state = .unknown
        self.lastState = .unknown
        self.totalBytesWritten = 0
        self.totalBytesExpectedToWrite = 0
        self.listeners = listeners ?? Array<CheapjackFile.Listener>()
        self.fileName = fileName ??  url?.lastPathComponent
        self.directoryName = directoryName ??  "Doc"
    }
    
    public convenience init(identifer: CheapjackFile.Identifier, url: URL, listeners: [CheapjackFile.Listener]? = nil) {
        let request = URLRequest(url: url)
        self.init(identifier: identifer, request: request, listeners: listeners)
    }
    
    
    // MARK: - CheapjackFile private setter methods
    
    public func addListener(_ listener: CheapjackFile.Listener) {
        listeners.append(listener)
    }
    
    public func removeListener(_ listener: CheapjackFile.Listener) {
        let listeners = self.listeners.filter { $0.delegate?.identifier != listener.delegate?.identifier}
        self.listeners = listeners
    }
    
    internal func setState(_ to: State) {
        state = to
    }
    
    internal func setTotalBytesWritten(_ bytes: Int64) {
        totalBytesWritten = bytes
    }
    
    internal func setTotalBytesExpectedToWrite(_ bytes: Int64) {
        totalBytesExpectedToWrite = bytes
    }
    
    // MARK: - CheapjackFile private notify methods
    
    fileprivate func notifyChangeStateListeners() {
        if let manager = manager {
            // CheapjackDelegate
            manager.delegate?.cheapjackManager(manager, didChangeState: lastState, to: state, forFile: self)
        }
        
        // CheapjackFile.Listener
        for listener in listeners {
            // CheapjackFileDelegate
            listener.delegate?.cheapjackFile(self, didChangeState: lastState, to: state)
            
            // CheapjackFile.Listener.DidChangeStateBlock
            if let didChangeStateBlock = listener.didChangeStateBlock {
                didChangeStateBlock(lastState, state)
            }
        }
    }
    
    fileprivate func notifyUpdateProgressListeners() {
        if let manager = manager {
            // CheapjackDelegate
            manager.delegate?.cheapjackManager(manager, didUpdateProgress: progress, totalBytesWritten: totalBytesWritten, totalBytesExpectedToWrite: totalBytesExpectedToWrite, forFile: self)
        }
        // CheapjackFile.Listener
        for listener in listeners {
            // CheapjackFileDelegate
            listener.delegate?.cheapjackFile(self, didUpdateProgress: progress, totalBytesWritten: totalBytesWritten, totalBytesExpectedToWrite: totalBytesExpectedToWrite)
            
            // CheapjackFile.Listener.DidUpdateProgressBlock
            if let didUpdateProgressBlock = listener.didUpdateProgressBlock {
                didUpdateProgressBlock(progress, totalBytesWritten, totalBytesExpectedToWrite)
            }
        }
    }
    
}

// File states default to .Unknown
public enum State {
    case unknown
    case waiting
    case downloading
    case paused(Data)
    case finished
    case cancelled
    case failed
}
extension State: Codable {
    private enum CodingKeys: String, CodingKey {
        case base, pausedData
    }
    private enum Base: String, Codable {
        case   unknown,waiting,failed,cancelled, downloading, finished, paused
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let base = try container.decode(Base.self, forKey: .base)
        
        switch base {
        case .cancelled:
            self = .cancelled
        case .downloading:
            self = .downloading
        case .finished:
            self = .finished
        case .paused:
            let pausedData = try container.decode(Data.self, forKey: .pausedData)
            self = .paused(pausedData)
        case .unknown:
            self = .unknown
        case .waiting:
            self = .waiting
        case .failed:
            self = .failed
            
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .cancelled:
            try container.encode(Base.cancelled, forKey: .base)
        case .downloading:
            try container.encode(Base.downloading, forKey: .base)
        case .finished:
            try container.encode(Base.finished, forKey: .base)
        case .paused(let data):
            try container.encode(Base.paused, forKey: .base)
            try container.encode(data, forKey: .pausedData)
        case .unknown:
            try container.encode(Base.unknown, forKey: .base)
        case .waiting:
            try container.encode(Base.waiting, forKey: .base)
        case .failed:
            try container.encode(Base.failed, forKey: .base)
            
        }
    }
}

