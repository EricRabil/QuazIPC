////  File.swift
//  
//
//  Created by Eric Rabil on 10/3/21.
//  
//

import Foundation

/// Facilitates the publishing of arbitrary NSXPCListeners
public class NSXPCDiscoveryServer: IPCPipeDelegate {
    public let name: String
    public let pipe: IPCPipe
    
    public var listeners: [String: NSXPCListener] = [:]
    
    public init?(name: String) {
        self.name = name
        
        guard let pipe = IPCPipe(local: name) else {
            return nil
        }
        
        self.pipe = pipe
        self.pipe.delegate = self
    }
    
    public func pipe(_ pipe: IPCPipe, receivedMessage message: xpc_object_t, auditToken: audit_token_t, replyID: UUID?, replyPipe: IPCPipe?) {
        guard let name = NSXPCDiscoveryRequest(object: message)?.connectionName else {
            replyPipe?.write(message: NSXPCDiscoveryResponse(endpoint: nil).object, replyID: replyID)
            return
        }
        
        replyPipe?.write(message: NSXPCDiscoveryResponse(connection: listeners[name]?.connection).object, replyID: replyID)
    }
}

/// Facilitates the retrieval of arbitrary NSXPCListeners
public class NSXPCDiscoveryClient {
    public let name: String
    public let pipe: IPCPipe
    
    public init?(name: String) {
        self.name = name
        
        guard let pipe = IPCPipe(remote: name) else {
            return nil
        }
        
        self.pipe = pipe
    }
    
    public func lookupEndpoint(named name: String) -> NSXPCListenerEndpoint? {
        guard let endpoint = NSXPCDiscoveryResponse(object: pipe.readwrite(message: NSXPCDiscoveryRequest(connectionName: name).object))?.endpoint else {
            return nil
        }
        
        return NSXPCListenerEndpoint(endpoint: endpoint)
    }
    
    public func lookupConnection(named name: String) -> NSXPCConnection? {
        guard let endpoint = lookupEndpoint(named: name) else {
            return nil
        }
        
        return NSXPCConnection(listenerEndpoint: endpoint)
    }
}
