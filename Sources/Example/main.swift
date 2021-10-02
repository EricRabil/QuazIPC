////  File.swift
//  
//
//  Created by Eric Rabil on 9/29/21.
//  
//

import Foundation
import QuazIPC
import CodableXPC

struct ServerHello: Codable {
    var type = "server-hello"
    var message: String
    
    init(message: String) {
        self.message = message
    }
}

struct ClientHello: Codable {
    var type = "client-hello"
    var message: String
    
    init(message: String) {
        self.message = message
    }
}

let mach_name = "sussy-ba"

if ProcessInfo.processInfo.arguments.contains("server") {
    guard let server_pipe = IPCPipe(local: mach_name) else {
        exit(-1)
    }
    
    class IPCDelegate: IPCPipeDelegate {
        func pipe(_ pipe: IPCPipe, receivedMessage message: xpc_object_t, auditToken: audit_token_t, replyID: UUID?, replyPipe: IPCPipe?) {
            do {
                try print(XPCDecoder.decode(ClientHello.self, message: message).message)
                
                try replyPipe!.write(ServerHello(message: "You're cool, also, i know who you are miss \(auditToken.pid) \(auditToken.auid)"), replyID: replyID)
            } catch {
                print("Failed to reply!", error)
            }
        }
        
        func pipe(_ pipe: IPCPipe, sendPortInvalidated sendPort: mach_port_t) {
            
        }
    }
    
    server_pipe.delegate = IPCDelegate()
    
    dispatchMain()
} else {
    guard let client_pipe = IPCPipe(remote: mach_name) else {
        exit(-1)
    }
    
    class IPCDelegate: IPCPipeDelegate {
        let client: IPCPipe
        
        init(client: IPCPipe) {
            self.client = client
        }
        
        func pipe(_ pipe: IPCPipe, receivedMessage message: xpc_object_t, auditToken: audit_token_t, replyID: UUID?, replyPipe: IPCPipe?) {
//            print(message.debugDescription ?? message.description)
        }
        
        var reconnecting = false
        
        func reconnect() {
            reconnecting = true
            
            if !client.reconnect(remote: mach_name) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: reconnect)
            } else {
                reconnecting = false
            }
        }
        
        func pipe(_ pipe: IPCPipe, sendPortInvalidated sendPort: mach_port_t) {
            if reconnecting {
                return
            }
            
            reconnect()
        }
        
        func run() {
            defer {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: run)
            }
            
            do {
                let reply: ServerHello = try client.readwrite(ClientHello(message: "Hey bestie!"))
                print(reply.message)
            } catch {
                if !client.sendPortValid {
                    return
                }
                
                print("failed to parse: \(error)")
            }
        }
    }
    
    let delegate = IPCDelegate(client: client_pipe)
    client_pipe.delegate = delegate
    client_pipe.forwardRepliesToDelegate = true
    
    delegate.run()
    
    dispatchMain()
}
