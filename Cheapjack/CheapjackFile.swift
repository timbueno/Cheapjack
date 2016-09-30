//
//  CheapjackFile.swift
//  TBDropbox
//
//  Created by Tim Bueno on 2015-08-04.
//  Copyright © 2015 Tim Bueno. All rights reserved.
//

import Foundation


public protocol CheapjackFileDelegate: class {
    func cheapjackFile(_ file: CheapjackFile, didChangeState from: CheapjackFile.State, to: CheapjackFile.State)
    func cheapjackFile(_ file: CheapjackFile, didUpdateProgress progress: Double, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64)
}


public func ==(lhs: CheapjackFile, rhs: CheapjackFile) -> Bool {
    return lhs.identifier == rhs.identifier
}


extension CheapjackFile.State: Equatable {
}

public func ==(lhs: CheapjackFile.State, rhs: CheapjackFile.State) -> Bool {
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


open class CheapjackFile: Equatable {
    
    // A listener may implement either of delegate and blocks.
    open class Listener {
        
        public typealias DidChangeStateBlock = (_ from: CheapjackFile.State, _ to: CheapjackFile.State) -> (Void)
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
    
    
    public typealias Identifier = String
    
    
    // MARK: - CheapjackFile public properties
    
    internal weak var manager: CheapjackManager?
    open var identifier: CheapjackFile.Identifier
    open var url: URL
    open var request: URLRequest
    
    open var progress: Double {
        if totalBytesExpectedToWrite > 0 {
            return Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        } else {
            return 0.0
        }
    }
    
    open var userInfo = Dictionary<String, AnyObject>()
    
    // MARK: - CheapjackFile public read-only properties
    
    open fileprivate(set) var lastState: CheapjackFile.State
    open fileprivate(set) var state: CheapjackFile.State {
        willSet {
            lastState = state
        }
        didSet {
            notifyChangeStateListeners()
        }
    }
    open fileprivate(set) var totalBytesExpectedToWrite: Int64
    open fileprivate(set) var totalBytesWritten: Int64 {
        didSet {
            notifyUpdateProgressListeners()
        }
    }
    
    // MARK: - CheapjackFile private properties
    
    internal var listeners: [CheapjackFile.Listener]
    internal var downloadTask: URLSessionDownloadTask?
    
    
    // MARK: - Initializers
    
    public init(identifier: CheapjackFile.Identifier, request: URLRequest, listeners: [CheapjackFile.Listener]? = nil) {
        self.identifier = identifier
        self.url = request.url!
        self.request = request
        self.state = .unknown
        self.lastState = .unknown
        self.totalBytesWritten = 0
        self.totalBytesExpectedToWrite = 0
        self.listeners = listeners ?? Array<CheapjackFile.Listener>()
    }
    
    public convenience init(identifer: CheapjackFile.Identifier, url: URL, listeners: [CheapjackFile.Listener]? = nil) {
        let request = URLRequest(url: url)
        self.init(identifier: identifer, request: request, listeners: listeners)
    }
    
    
    // MARK: - CheapjackFile private setter methods
    
    fileprivate func addListener(_ listener: CheapjackFile.Listener) {
        listeners.append(listener)
    }
    
    internal func setState(_ to: CheapjackFile.State) {
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
