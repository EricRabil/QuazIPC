//  IPCPipe.swift
//  Wrapper class around xpc_pipe, allowing you to have xpc-style communication with plain mach ports

import XPC
import Foundation

public protocol IPCPipeDelegate {
    func pipe(_ pipe: IPCPipe, receivedMessage message: xpc_object_t, auditToken: audit_token_t, replyID: UUID?, replyPipe: IPCPipe?)
    func pipe(_ pipe: IPCPipe, failedWriteWithError error: CInt)
    func pipe(_ pipe: IPCPipe, failedReceiveWithError error: CInt)
    func pipe(_ pipe: IPCPipe, sendPortInvalidated sendPort: mach_port_t)
}

// Default implementation for error handlers (living dangerously)
public extension IPCPipeDelegate {
    func pipe(_ pipe: IPCPipe, failedWriteWithError error: CInt) {}
    func pipe(_ pipe: IPCPipe, failedReceiveWithError error: CInt) {}
    func pipe(_ pipe: IPCPipe, sendPortInvalidated sendPort: mach_port_t) {}
}

@_silgen_name("dispatch_get_current_queue")
func dispatch_get_current_queue() -> Unmanaged<DispatchQueue>

public class IPCPipe {
    public typealias ReplyBlock = (xpc_object_t, audit_token_t, IPCPipe?) -> ()
    
    public var errno: CInt = 0
    public var delegate: IPCPipeDelegate?
    public var forwardRepliesToDelegate = false
    
    public var sendPortValid: Bool {
        mach_port_send_valid(send_port)
    }
    
    // All pipes have their own DispatchQueue whose parent is the superqueue
    private static let queue = DispatchQueue(label: "com.ericrabil.quazipc.superqueue", qos: .userInitiated, attributes: [], autoreleaseFrequency: frequency)
    
    // Communication context
    private var pipe: xpc_pipe_t
    private var send_port: mach_port_t = 0
    private var recv_port: mach_port_t = 0
    
    // State management
    private var replyBlocks: [UUID: ReplyBlock] = [:]
    private lazy var source: DispatchSourceMachReceive = {
        let source = DispatchSource.makeMachReceiveSource(port: recv_port, queue: Self.queue)
        
        source.setEventHandler(handler: receive)
        
        source.setCancelHandler {
            
        }
        
        source.setRegistrationHandler {
            
        }
        
        return source
    }()
    
    private init(delegate: IPCPipeDelegate? = nil, pipe: xpc_pipe_t, send_port: mach_port_t = 0, recv_port: mach_port_t = 0, source: DispatchSourceMachReceive? = nil) {
        self.delegate = delegate
        self.pipe = pipe
        self.send_port = send_port
        self.recv_port = recv_port
        if let source = source {
            self.source = source
        }
    }
    
    // Used to create a contextual pipe off of an existing DispatchSource/port setup
    private convenience init(send_port: mach_port_t, inheriting basePipe: IPCPipe) {
        self.init(delegate: basePipe.delegate, pipe: xpc_pipe_create_from_port(send_port, 0), send_port: send_port, recv_port: basePipe.recv_port, source: basePipe.source)
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
            
            var audit_token = audit_token_t()
            xpc_dictionary_get_audit_token(object, &audit_token)
            
            if let replyID = replyID, let replyBlock = replyBlocks.removeValue(forKey: replyID) {
                // Pass reply to the pending block
                replyBlock(message, audit_token, replyPipe)
                
                if !forwardRepliesToDelegate {
                    return
                }
            }
            
            // Pass message to the delegate
            mainDelegate { $0.pipe(self, receivedMessage: message, auditToken: audit_token, replyID: replyID, replyPipe: replyPipe) }
        } else {
            self.errno = result
            mainDelegate { $0.pipe(self, failedReceiveWithError: result) }
        }
    }
    
    // MARK: - Writing
    
    public func write(message: xpc_object_t, replyID: UUID? = nil) {
        if !sendPortValid {
            if let replyID = replyID {
                replyBlocks.removeValue(forKey: replyID)?(xpc_null_create(), audit_token_t(), nil)
            }
            
            mainDelegate { $0.pipe(self, sendPortInvalidated: send_port) }
            return
        }
        
        errno = xpc_pipe_routine_async(pipe, xpc_pack(recv_port: recv_port, reply_id: replyID, message: message), recv_port)
        if _slowPath(errno != 0) {
            mainDelegate { $0.pipe(self, failedWriteWithError: errno) }
        }
    }
    
    /// Writes a message and invokes a callback when a response is received
    public func write(message: xpc_object_t, queue: DispatchQueue = .main, replyBlock: @escaping ReplyBlock) {
        let replyID = UUID()
        
        if queue == Self.queue {
            replyBlocks[replyID] = replyBlock
        } else {
            replyBlocks[replyID] = { msg, token, pipe in
                queue.async {
                    replyBlock(msg, token, pipe)
                }
            }
        }
        
        write(message: message, replyID: replyID)
    }
    
    private func main<P>(_ callback: @autoclosure () -> P) {
        if dispatch_get_current_queue().takeUnretainedValue() == .main {
            let _ = callback()
        } else {
            let _ = DispatchQueue.main.sync(execute: callback)
        }
    }
    
    private func mainDelegate<P>(_ callback: (IPCPipeDelegate) -> P) {
        guard let delegate = delegate else {
            return
        }
        
        main(callback(delegate))
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
    
    /// Register the receive port in an arbitrary bootstrap port
    func x_bootstrap_register(_ bootstrap_port: mach_port_t, name: UnsafePointer<CChar>) -> kern_return_t {
        bootstrap_register(bootstrap_port, name, recv_port)
    }
    
    func reconnect(remote name: UnsafePointer<CChar>) -> Bool {
        var port: mach_port_t = 0
        
        guard bootstrap_look_up(bootstrap_port, name, &port) == KERN_SUCCESS else {
            return false
        }
        
        send_port = port
        xpc_pipe_invalidate(self.pipe)
        pipe = xpc_pipe_create_from_port(port, 0)
        errno = 0
        
        return true
    }
}

// MARK: - Synchronous Helpers
public extension IPCPipe {
    /// Sends a message and synchronously waits for a response
    func readwrite(message: xpc_object_t) -> (output: xpc_object_t, token: audit_token_t, replyPipe: IPCPipe?) {
        let semaphore = DispatchSemaphore(value: 0)
        let original = pipe
        var result = xpc_null_create()
        var token = audit_token_t()
        var pipe: IPCPipe? = nil
        
        write(message: message, queue: Self.queue) { response, responseToken, replyPipe in
            result = response
            token = responseToken
            pipe = replyPipe
            semaphore.signal()
        }
        
        semaphore.wait()
        
        if original !== self.pipe {
            // the connection was replaced, and the message failed
            return readwrite(message: message)
        }
        
        // fix memory leak
        return (result, token, pipe)
    }
    
    /// Sends a message and synchronously waits for a response
    func readwrite(message: xpc_object_t) -> xpc_object_t {
        let (result, _, _) = readwrite(message: message)
        return result
    }
}
