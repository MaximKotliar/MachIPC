//
//  MachCommon.swift
//  SubProcess
//
//  Created by Maxim Kotliar on 12.11.2025.
//

import Darwin.Mach

@inline(__always)
func alignMemory(size: Int, alignment: Int) -> Int {
    (size + (alignment - 1)) & ~(alignment - 1)
}

@inline(__always)
let mach_msg_copy_send_bits = MACH_MSGH_BITS_REMOTE(UInt32(MACH_MSG_TYPE_COPY_SEND))
