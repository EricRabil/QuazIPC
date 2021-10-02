////  File.swift
//  
//
//  Created by Eric Rabil on 10/2/21.
//  
//

import Foundation

typealias xpc_pipe_t = xpc_object_t

func mach_port_receiving() -> mach_port_t? {
    var port: mach_port_t = 0
    
    guard mach_port_allocate(mach_task_self_, MACH_PORT_RIGHT_RECEIVE, &port) == 0 else {
        return nil
    }
    
    mach_port_insert_right(mach_task_self_, port, port, mach_msg_type_name_t(MACH_MSG_TYPE_MAKE_SEND))
    
    return port
}

var frequency: DispatchQueue.AutoreleaseFrequency {
    if #available(macOS 10.12, *) {
        return .workItem
    } else {
        return .inherit
    }
}
