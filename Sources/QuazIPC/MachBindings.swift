//  mach_bindings.swift
//
//  Y'know, you're not supposed to use @_silgen_name. But it works, and "don't use it" isn't good enough
//  https://www.youtube.com/watch?v=aj0z8jY1LY8
//
//  Created by Eric Rabil on 10/2/21.
//  

import Foundation

@_silgen_name("xpc_pipe_create_from_port")
func xpc_pipe_create_from_port(_ port: mach_port_t, _ flags: UInt64) -> xpc_pipe_t

@_silgen_name("xpc_pipe_create")
func xpc_pipe_create(_ name: UnsafePointer<CChar>, _ flags: UInt64) -> xpc_pipe_t

@_silgen_name("bootstrap_register")
func bootstrap_register(_ bs_port: mach_port_t, _ name: UnsafePointer<CChar>, _ port: mach_port_t) -> kern_return_t

@_silgen_name("bootstrap_look_up")
func bootstrap_look_up(_ bs_port: mach_port_t, _ name: UnsafePointer<CChar>, _ port: UnsafeMutablePointer<mach_port_t>) -> kern_return_t

@_silgen_name("xpc_pipe_receive")
func xpc_pipe_receive(_ p: mach_port_t, _ message: UnsafeMutablePointer<xpc_object_t>, _ flags: UInt64) -> CInt

@_silgen_name("xpc_pipe_routine_async")
func xpc_pipe_routine_async(_ pipe: xpc_pipe_t, _ message: xpc_object_t, _ replyp: mach_port_t) -> CInt

@_silgen_name("xpc_pipe_try_receive")
func xpc_pipe_try_receive(_ pipe: mach_port_t, _ message: UnsafeMutablePointer<xpc_object_t>, _ recvp: UnsafeMutablePointer<mach_port_t>, _ callout: @convention(c) (UnsafeMutablePointer<mach_msg_header_t>, UnsafeMutablePointer<mach_msg_header_t>) -> boolean_t, _ maxmsgsz: size_t, _ flags: UInt64) -> CInt

@_silgen_name("xpc_dictionary_set_mach_send")
public func xpc_dictionary_set_mach_send(_ dictionary: xpc_object_t, _ key: UnsafePointer<CChar>, _ port: mach_port_t)

@_silgen_name("xpc_dictionary_copy_mach_send")
public func xpc_dictionary_copy_mach_send(_ dictionary: xpc_object_t, _ key: UnsafePointer<CChar>) -> mach_port_t

@_silgen_name("xpc_pipe_invalidate")
func xpc_pipe_invalidate(_ pipe: xpc_pipe_t)

private let MACH_PORT_TYPE_SEND_RIGHTS: UInt32 = 65536

func mach_port_send_valid(_ port: mach_port_t) -> Bool {
    var type: mach_port_type_t = 0
    
    if mach_port_type(mach_task_self_, port, &type) != KERN_SUCCESS || (0 == (type & MACH_PORT_TYPE_SEND_RIGHTS)) {
        return false
    }
    
    return true
}
