//  IPCPipe.swift
//  Wrapper class around xpc_pipe, allowing you to have xpc-style communication with plain mach ports

import XPC
import Foundation

public protocol IPCPipeDelegate {
    func pipe(_ pipe: IPCPipe, receivedMessage message: xpc_object_t, replyPipe: IPCPipe?)
    func pipe(_ pipe: IPCPipe, failedWriteWithError error: CInt)
    func pipe(_ pipe: IPCPipe, failedReceiveWithError error: CInt)
}

// Default implementation for error handlers (living dangerously)
public extension IPCPipeDelegate {
    func pipe(_ pipe: IPCPipe, failedWriteWithError error: CInt) {}
    func pipe(_ pipe: IPCPipe, failedReceiveWithError error: CInt) {}
}

public class IPCPipe {
    public typealias ReplyBlock = (xpc_object_t, IPCPipe?) -> ()
    
    public var errno: CInt = 0
    public var delegate: IPCPipeDelegate?
    public var forwardRepliesToDelegate = false
    
    // All pipes have their own DispatchQueue whose parent is the superqueue
    private static let superqueue = DispatchQueue(label: "com.ericrabil.quazipc.superqueue")
    
    // Communication context
    private var pipe: xpc_pipe_t
    private var send_port: mach_port_t = 0
    private var recv_port: mach_port_t = 0
    
    // State management
    private var replyBlocks: [UUID: ReplyBlock] = [:]
    private lazy var queue: DispatchQueue = DispatchQueue(label: "com.ericrabil.quazipc.pipe", qos: .userInitiated, attributes: [], autoreleaseFrequency: frequency, target: IPCPipe.superqueue)
    private lazy var source: DispatchSourceMachReceive = {
        let source = DispatchSource.makeMachReceiveSource(port: recv_port, queue: queue)
        
        source.setEventHandler(handler: receive)
        
        source.setCancelHandler {
            
        }
        
        source.setRegistrationHandler {
            
        }
        
        return source
    }()
    
    private init(delegate: IPCPipeDelegate? = nil, pipe: xpc_pipe_t, send_port: mach_port_t = 0, recv_port: mach_port_t = 0, queue: DispatchQueue? = nil, source: DispatchSourceMachReceive? = nil) {
        self.delegate = delegate
        self.pipe = pipe
        self.send_port = send_port
        self.recv_port = recv_port
        if let source = source {
            self.source = source
        }
        if let queue = queue {
            self.queue = queue
        }
    }
    
    // Used to create a contextual pipe off of an existing DispatchSource/port setup
    private convenience init(send_port: mach_port_t, inheriting basePipe: IPCPipe) {
        self.init(delegate: basePipe.delegate, pipe: xpc_pipe_create_from_port(send_port, 0), send_port: send_port, recv_port: basePipe.recv_port, queue: basePipe.queue, source: basePipe.source)
    }
    
    // MARK: - Reading
    
    private func receive() {
        var object: xpc_object_t = xpc_null_create()
        
        let result = xpc_pipe_receive(recv_port, &object, 0)
        if result == 0 {
            guard let (reply_port, replyID, message) = xpc_unpack(object: object) else {
                return
            }
            
            let replyPipe: IPCPipe? = {
                guard reply_port != MACH_PORT_NULL else {
                    return nil
                }
                
                return IPCPipe(send_port: reply_port, inheriting: self)
            }()
            
            if let replyID = replyID, let replyBlock = replyBlocks.removeValue(forKey: replyID) {
                // Pass reply to the pending block
                replyBlock(message, replyPipe)
                
                if !forwardRepliesToDelegate {
                    return
                }
            }
            
            // Pass message to the delegate
            delegate?.pipe(self, receivedMessage: message, replyPipe: replyPipe)
        } else {
            self.errno = result
            self.delegate?.pipe(self, failedReceiveWithError: result)
        }
    }
    
    // MARK: - Writing
    
    private func write(message: xpc_object_t, replyID: UUID? = nil) {
        errno = xpc_pipe_routine_async(pipe, xpc_pack(recv_port: recv_port, reply_id: replyID, message: message), recv_port)
        if _slowPath(errno != 0) {
            delegate?.pipe(self, failedWriteWithError: errno)
        }
    }
    
    /// Writes a message
    public func write(message: xpc_object_t) {
        write(message: message, replyID: nil)
    }
    
    /// Writes a message and invokes a callback when a response is received
    public func write(message: xpc_object_t, replyBlock: @escaping ReplyBlock) {
        let replyID = UUID()
        replyBlocks[replyID] = replyBlock
        write(message: message, replyID: replyID)
    }
}

// MARK: - Port Wrapping
public extension IPCPipe {
    convenience init(send_port: mach_port_t, recv_port: mach_port_t) {
        self.init(pipe: xpc_pipe_create_from_port(send_port, 0), send_port: send_port, recv_port: recv_port)
        source.resume()
    }
}

// MARK: - Bootstrap Integration
public extension IPCPipe {
    convenience init?(local name: UnsafePointer<CChar>) {
        guard let port = mach_port_receiving(), bootstrap_register(bootstrap_port, name, port) == KERN_SUCCESS else {
            return nil
        }
        
        self.init(send_port: 0, recv_port: port)
    }
    
    convenience init?(remote name: UnsafePointer<CChar>) {
        var port: mach_port_t = 0
        
        guard bootstrap_look_up(bootstrap_port, name, &port) == KERN_SUCCESS, let recv_port = mach_port_receiving() else {
            return nil
        }
        
        self.init(send_port: port, recv_port: recv_port)
    }
}

// MARK: - Synchronous Helpers
public extension IPCPipe {
    /// Sends a message and synchronously waits for a response
    func readwrite(message: xpc_object_t) -> (output: xpc_object_t, replyPipe: IPCPipe?) {
        let semaphore = DispatchSemaphore(value: 0)
        var result = xpc_null_create()
        var pipe: IPCPipe? = nil
        
        write(message: message) { response, replyPipe in
            result = response
            pipe = replyPipe
            semaphore.signal()
        }
        
        semaphore.wait()
        // fix memory leak
        return (result, pipe)
    }
    
    /// Sends a message and synchronously waits for a response
    func readwrite(message: xpc_object_t) -> xpc_object_t {
        let (result, _) = readwrite(message: message)
        return result
    }
}
