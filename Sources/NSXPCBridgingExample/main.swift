import Foundation
import QuazIPC

let mach_name = "xpc-connection-shuttle"
let xpc_name = "kittens"

@objc public protocol MyServiceProtocol {
    func upperCaseString(_ string: String, withReply reply: @escaping (String) -> Void)
}

if ProcessInfo.processInfo.arguments.contains("server") {
    guard let server = NSXPCDiscoveryServer(name: mach_name) else {
        exit(-1)
    }
    
    let listener = NSXPCListener.anonymous()
    
    server.listeners[xpc_name] = listener
    
    class IPCDelegate: NSObject, NSXPCListenerDelegate, MyServiceProtocol {
        func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
            print(newConnection)
            newConnection.exportedInterface = NSXPCInterface(with: MyServiceProtocol.self)
            newConnection.exportedObject = self
            newConnection.resume()
            return true
        }
        
        func upperCaseString(_ string: String, withReply reply: @escaping (String) -> Void) {
            reply(string.uppercased())
        }
    }
    
    listener.resume()
    let delegate = IPCDelegate()
    listener.delegate = delegate
    
    dispatchMain()
} else {
    guard let discoveryServer = NSXPCDiscoveryClient(name: mach_name) else {
        exit(-1)
    }
    
    guard let connection = discoveryServer.lookupConnection(named: xpc_name) else {
        print("omg")
        exit(-2)
    }
    
    connection.remoteObjectInterface = NSXPCInterface(with: MyServiceProtocol.self)
    connection.resume()
    
    let service = connection.remoteObjectProxyWithErrorHandler { err in
        print(err)
    } as? MyServiceProtocol
    
    print(connection)
    
    service?.upperCaseString("asdf") { str in
        print(str)
    }
    
    dispatchMain()
}
