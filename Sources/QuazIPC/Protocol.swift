////  File.swift
//  
//
//  Created by Eric Rabil on 10/2/21.
//  
//

import Foundation
import XPC

private extension UUID {
    var xpc: xpc_object_t {
        var bytes = [UInt8](repeating: 0, count: 16)
        (self as NSUUID).getBytes(&bytes)
        return xpc_uuid_create(bytes)
    }
}

private extension StaticString {
    var cString: UnsafePointer<CChar> {
        UnsafeRawPointer(utf8Start).bindMemory(to: CChar.self, capacity: utf8CodeUnitCount)
    }
}

private extension xpc_object_t {
    // Only call for xpc_dictionary_t, you have been warned
    func contains(key: UnsafePointer<CChar>) -> Bool {
        xpc_dictionary_get_value(self, key) != nil
    }
}

private let reply_port_key = ("reply_port" as StaticString).cString
private let reply_id_key = ("reply_id" as StaticString).cString
private let message_key = ("message" as StaticString).cString

func xpc_pack(recv_port: mach_port_t, reply_id: UUID?, message: xpc_object_t) -> xpc_object_t {
    let dictionary = xpc_dictionary_create(nil, nil, 0)
    
    xpc_dictionary_set_mach_send(dictionary, reply_port_key, recv_port)
    if let reply_id = reply_id {
        xpc_dictionary_set_value(dictionary, reply_id_key, reply_id.xpc)
    }
    xpc_dictionary_set_value(dictionary, message_key, message)
    
    return dictionary
}

func xpc_unpack(object: xpc_object_t) -> (reply_port: mach_port_t, reply_id: UUID?, message: xpc_object_t)? {
    let reply_port = xpc_dictionary_copy_mach_send(object, reply_port_key)
    let reply_id = object.contains(key: reply_id_key) ? NSUUID(uuidBytes: xpc_dictionary_get_uuid(object, reply_id_key)) as UUID : nil
    guard let message = xpc_dictionary_get_value(object, message_key) else {
        return nil
    }
    
    return (reply_port, reply_id, message)
}
