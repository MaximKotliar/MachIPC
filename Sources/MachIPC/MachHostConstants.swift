//
//  MachHostConstants.swift
//  MachIPC
//
//  Created by Maxim Kotliar on 16.11.2025.
//

import Darwin.Mach

enum MachHostConstants {
    @inline(__always)
    static let idleReceiverThreadTimeout: mach_msg_timeout_t = 1000 // 1sec
}
