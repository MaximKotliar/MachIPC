//
//  MachBridged.swift
//  MachIPC
//
//  Created by Maxim Kotliar on 15.11.2025.
//

import Darwin.Mach

@_silgen_name("bootstrap_check_in")
func bootstrap_check_in(
    _ bp: mach_port_t,
    _ service_name: UnsafePointer<CChar>,
    _ sp: UnsafeMutablePointer<mach_port_t>
) -> kern_return_t

@_silgen_name("bootstrap_look_up")
func bootstrap_look_up(_ bp: mach_port_t,
                       _ name: UnsafePointer<CChar>,
                       _ sp: UnsafeMutablePointer<mach_port_t>) -> kern_return_t


@_silgen_name("bootstrap_port")
nonisolated(unsafe) var bootstrap_port: mach_port_t

// Import bridge functions from DarwinBridge using @_silgen_name
@_silgen_name("MACH_MSGH_BITS_REMOTE_BRIDGE")
func MACH_MSGH_BITS_REMOTE_BRIDGE(_ remote: mach_msg_type_name_t) -> mach_msg_bits_t

@_silgen_name("MACH_MSGH_BITS_LOCAL_BRIDGE")
func MACH_MSGH_BITS_LOCAL_BRIDGE(_ local: mach_msg_type_name_t) -> mach_msg_bits_t

@_silgen_name("MACH_MSGH_BITS_BRIDGE")
func MACH_MSGH_BITS_BRIDGE(_ remote: mach_msg_type_name_t, _ local: mach_msg_type_name_t) -> mach_msg_bits_t

@_silgen_name("MACH_MSG_SIZE_MIN_BRIDGE")
nonisolated(unsafe) var MACH_MSG_SIZE_MIN_BRIDGE: mach_msg_size_t

// Use bridge functions from DarwinBridge
@inline(__always)
public func MACH_MSGH_BITS_REMOTE(_ remote: mach_msg_bits_t) -> mach_msg_bits_t {
    return MACH_MSGH_BITS_REMOTE_BRIDGE(mach_msg_type_name_t(remote))
}

@inline(__always)
public func MACH_MSGH_BITS_LOCAL(_ local: mach_msg_bits_t) -> mach_msg_bits_t {
    return MACH_MSGH_BITS_LOCAL_BRIDGE(mach_msg_type_name_t(local))
}

@inline(__always)
public func MACH_MSGH_BITS(_ remote: mach_msg_bits_t, _ local: mach_msg_bits_t) -> mach_msg_bits_t {
    return MACH_MSGH_BITS_BRIDGE(mach_msg_type_name_t(remote), mach_msg_type_name_t(local))
}
