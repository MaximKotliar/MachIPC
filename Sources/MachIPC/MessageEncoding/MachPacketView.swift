//
//  MachPacketView.swift
//  SubProcess
//
//  Created by Maxim Kotliar on 13.11.2025.
//

import Foundation

struct MachPacketView {
    
    let header: mach_msg_header_t
    let payloadSize: Int64
    // payload should be placed next after payloadSize
    
    static var sizeWithoutData: Int { MemoryLayout<MachPacketView>.size }
}
