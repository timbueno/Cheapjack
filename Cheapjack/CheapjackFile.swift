//
//  CheapjackFile.swift
//  TBDropbox
//
//  Created by Tim Bueno on 2015-08-04.
//  Copyright © 2015 Tim Bueno. All rights reserved.
//

import Foundation


public protocol CheapjackFileDelegate: class {
    func cheapjackFile(file: CheapjackFile, didChangeState from: CheapjackFile.State, to: CheapjackFile.State)
    func cheapjackFile(file: CheapjackFile, didUpdateProgress progress: Double, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64)
}


public func ==(lhs: CheapjackFile, rhs: CheapjackFile) -> Bool {
    return lhs.identifier == rhs.identifier
}


extension CheapjackFile.State: Equatable {
}

public func ==(lhs: CheapjackFile.State, rhs: CheapjackFile.State) -> Bool {
    switch (lhs, rhs) {
    case (let .Paused(data1), let .Paused(data2)):
        return data1 == data2
    case (.Unknown, .Unknown):
        return true
    case (.Waiting, .Waiting):
        return true
    case (.Downloading, .Downloading):
        return true
    case (.Finished, .Finished):
        return true
    case (.Cancelled, .Cancelled):
        return true
    case (.Failed, .Failed):
        return true
    default:
        return false
    }
}


public class CheapjackFile: Equatable {
    
    // A listener may implement either of delegate and blocks.
    public class Listener {
        
        public typealias DidChangeStateBlock = (from: CheapjackFile.State, to: CheapjackFile.State) -> (Void)
        public typealias DidUpdateProgressBlock = (progress: Double, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) -> (Void)
        
        
        public weak var delegate: CheapjackFileDelegate?
        public var didChangeStateBlock: CheapjackFile.Listener.DidChangeStateBlock?
        public var didUpdateProgressBlock: CheapjackFile.Listener.DidUpdateProgressBlock?
        
        public init(delegate: CheapjackFileDelegate? = nil, didChangeStateBlock: CheapjackFile.Listener.DidChangeStateBlock? = nil, didUpdateProgressBlock: CheapjackFile.Listener.DidUpdateProgressBlock? = nil) {
            self.delegate = delegate
            self.didChangeStateBlock = didChangeStateBlock
            self.didUpdateProgressBlock = didUpdateProgressBlock
        }
        
    }
    
    
    // File states default to .Unknown
    public enum State {
        case Unknown
        case Waiting
        case Downloading
        case Paused(NSData)
        case Finished
        case Cancelled
        case Failed
    }
    
    
    public typealias Identifier = String
    
    
    // MARK: - CheapjackFile public properties
    
    internal weak var manager: CheapjackManager?
    public var identifier: CheapjackFile.Identifier
    public var url: NSURL
    public var request: NSURLRequest
    
    public var progress: Double {
        if totalBytesExpectedToWrite > 0 {
            return Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        } else {
            return 0.0
        }
    }
    
    public var userInfo = Dictionary<String, AnyObject>()
    
    // MARK: - CheapjackFile public read-only properties
    
    public private(set) var lastState: CheapjackFile.State
    public private(set) var state: CheapjackFile.State {
        willSet {
            lastState = state
        }
        didSet {
            notifyChangeStateListeners()
        }
    }
    public private(set) var totalBytesExpectedToWrite: Int64
    public private(set) var totalBytesWritten: Int64 {
        didSet {
            notifyUpdateProgressListeners()
        }
    }
    
    // MARK: - CheapjackFile private properties
    
    internal var listeners: [CheapjackFile.Listener]
    internal var downloadTask: NSURLSessionDownloadTask?
    
    
    // MARK: - Initializers
    
    public init(identifier: CheapjackFile.Identifier, request: NSURLRequest, listeners: [CheapjackFile.Listener]? = nil) {
        self.identifier = identifier
        self.url = request.URL!
        self.request = request
        self.state = .Unknown
        self.lastState = .Unknown
        self.totalBytesWritten = 0
        self.totalBytesExpectedToWrite = 0
        self.listeners = listeners ?? Array<CheapjackFile.Listener>()
    }
    
    public convenience init(identifer: CheapjackFile.Identifier, url: NSURL, listeners: [CheapjackFile.Listener]? = nil) {
        let request = NSURLRequest(URL: url)
        self.init(identifier: identifer, request: request, listeners: listeners)
    }
    
    
    // MARK: - CheapjackFile private setter methods
    
    private func addListener(listener: CheapjackFile.Listener) {
        listeners.append(listener)
    }
    
    internal func setState(to: CheapjackFile.State) {
        state = to
    }
    
    internal func setTotalBytesWritten(bytes: Int64) {
        totalBytesWritten = bytes
    }
    
    internal func setTotalBytesExpectedToWrite(bytes: Int64) {
        totalBytesExpectedToWrite = bytes
    }
    
    // MARK: - CheapjackFile private notify methods
    
    private func notifyChangeStateListeners() {
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
                didChangeStateBlock(from: lastState, to: state)
            }
        }
    }
    
    private func notifyUpdateProgressListeners() {
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
                didUpdateProgressBlock(progress: progress, totalBytesWritten: totalBytesWritten, totalBytesExpectedToWrite: totalBytesExpectedToWrite)
            }
        }
    }
    
}