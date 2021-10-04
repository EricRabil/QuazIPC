////  File.swift
//  
//
//  Created by Eric Rabil on 10/4/21.
//  
//

import Foundation

internal extension NSXPCListener {
    var connection: xpc_connection_t {
        get {
            unsafeBitCast(self, to: UnsafeMutableRawPointer.self).advanced(by: 0x8).assumingMemoryBound(to: xpc_connection_t.self).pointee
        }
        set {
            unsafeBitCast(self, to: UnsafeMutableRawPointer.self).advanced(by: 0x8).assumingMemoryBound(to: xpc_connection_t.self).pointee = newValue
        }
    }
}

internal extension NSXPCListenerEndpoint {
    var endpoint: xpc_endpoint_t {
        get {
            unsafeBitCast(self, to: UnsafeMutableRawPointer.self).advanced(by: 0x8).assumingMemoryBound(to: xpc_endpoint_t.self).pointee
        }
        set {
            unsafeBitCast(self, to: UnsafeMutableRawPointer.self).advanced(by: 0x8).assumingMemoryBound(to: xpc_endpoint_t.self).pointee = newValue
        }
    }
    
    convenience init(endpoint: xpc_endpoint_t) {
        self.init()
        self.endpoint = endpoint
    }
}
