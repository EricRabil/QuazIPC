////  File.swift
//  
//
//  Created by Eric Rabil on 9/29/21.
//  
//

import Foundation
import QuazIPC

@objc protocol IPCProtocol {
    func hello()
}

extension NSXPCListenerEndpoint {
    var _endpoint: xpc_endpoint_t {
        get {
            unsafeBitCast(perform(Selector("_endpoint")).takeUnretainedValue(), to: xpc_endpoint_t.self)
        }
        set {
            perform(Selector("_setEndpoint:"), with: newValue)
        }
    }
}

if ProcessInfo.processInfo.arguments.contains("server") {
    guard let server_pipe = IPCPipe(local: "sussy-baka") else {
        exit(-1)
    }
    
    class IPCDelegate: NSObject, NSXPCListenerDelegate, IPCProtocol, IPCPipeDelegate {
        let listener: NSXPCListener
        
        init(listener: NSXPCListener) {
            self.listener = listener
        }
        
        func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
            true
        }
        
        func pipe(_ pipe: IPCPipe, receivedMessage message: xpc_object_t, replyPipe: IPCPipe?) {
            let response = xpc_dictionary_create(nil, nil, 0)
//            xpc_dictionary_set_mach_send(response, "endpoint", xpc_endpoint_copy_listener_port_4sim(listener.endpoint._endpoint))
            xpc_dictionary_set_value(response, "endpoint", listener.endpoint._endpoint)
            xpc_dictionary_set_value(response, "reply_id", xpc_dictionary_get_value(message, "reply_id"))
            replyPipe!.write(message: response)
        }
        
        func hello() {
            print("its me")
        }
    }
    
    let listener = NSXPCListener.anonymous()
    let delegate = IPCDelegate(listener: listener)
    listener.delegate = delegate
    server_pipe.delegate = delegate
    
    listener.resume()
    
    dispatchMain()
} else {
    guard let client_pipe = IPCPipe(remote: "sussy-baka") else {
        exit(-1)
    }
    
    let object = xpc_dictionary_create(nil, nil, 0)
    xpc_dictionary_set_value(object, "hey", xpc_string_create("asdf"))
    let endpoint = xpc_dictionary_get_value(client_pipe.readwrite(message: object), "endpoint")! as xpc_endpoint_t
    print(endpoint)
    let nsEndpoint = NSXPCListenerEndpoint()
    nsEndpoint._endpoint = endpoint
    
    print(xpc_connection_create_from_endpoint(endpoint))
    
    let connection = NSXPCConnection(listenerEndpoint: nsEndpoint)
    
    connection.remoteObjectInterface = NSXPCInterface(with: IPCProtocol.self)
    
    connection.resume()
    
    let interface = connection.remoteObjectProxyWithErrorHandler { error in
        print(error)
    } as? IPCProtocol
    
    interface?.hello()
    
    print(connection)
    print("ha")
}
