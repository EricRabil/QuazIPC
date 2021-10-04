////  File.swift
//  
//
//  Created by Eric Rabil on 10/4/21.
//  
//

import Foundation

internal struct NSXPCDiscoveryRequest {
    init(connectionName: String) {
        self.connectionName = connectionName
    }
    
    init?(object: xpc_object_t) {
        guard xpc_get_type(object) == XPC_TYPE_DICTIONARY, let string = xpc_dictionary_get_string(object, "connection-name") else {
            return nil
        }
        
        connectionName = String(cString: string)
    }
    
    var connectionName: String
    
    var object: xpc_object_t {
        let dictionary = xpc_dictionary_create(nil, nil, 0)
        
        xpc_dictionary_set_string(dictionary, "connection-name", connectionName)
        
        return dictionary
    }
}

internal struct NSXPCDiscoveryResponse {
    init(connection: xpc_connection_t?) {
        guard let connection = connection else {
            endpoint = nil
            return
        }
        
        endpoint = xpc_endpoint_create(connection)
    }
    
    init(endpoint: xpc_endpoint_t?) {
        self.endpoint = endpoint
    }
    
    init?(object: xpc_object_t) {
        guard xpc_get_type(object) == XPC_TYPE_DICTIONARY else {
            return nil
        }
        
        if let value = xpc_dictionary_get_value(object, "endpoint"), xpc_get_type(value) == XPC_TYPE_ENDPOINT {
            endpoint = value
        }
    }
    
    var endpoint: xpc_endpoint_t?
    
    var object: xpc_object_t {
        let dictionary = xpc_dictionary_create(nil, nil, 0)
        
        if let endpoint = endpoint {
            xpc_dictionary_set_value(dictionary, "endpoint", endpoint)
        }
        
        return dictionary
    }
}
