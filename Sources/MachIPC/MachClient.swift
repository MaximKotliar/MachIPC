//
//  MachClient.swift
//  SubProcess
//
//  Created by Maxim Kotliar on 12.11.2025.
//

import Darwin.Mach

public final class MachClient<Message: MachPayloadProvider> {
    
    enum Host {
        case local(Weak<MachHost<Message>>)
        case remote(mach_port_t)
    }
    
    public let logger: Logger?
    private let endpoint: String
    
    private var host: Host?
    
    public init(endpoint: String, logger: Logger? = nil) throws {
        self.endpoint = endpoint
        self.logger = logger
        self.host = try resolveHost(for: endpoint)
    }
    
    private func resolveHost(for endpoint: String) throws -> Host {
        if let localReceiver: MachHost<Message> = MachLocalhostRegistry.shared.localReceiver(for: endpoint) {
            logger?.log(1, "Connected to local endpoint.")
            return .local(Weak(localReceiver))
        } else {
            var kr: Int32 = 0
            var port: mach_port_t = 0
            kr = bootstrap_look_up(bootstrap_port, endpoint, &port)
            guard kr == KERN_SUCCESS else {
                throw MachError(Int(kr), "Failed to look up endpoint: \(endpoint)")
            }
            logger?.log(1, "Connected to remote endpoint.")
            return .remote(port)
        }
    }
    
    /// Send a message to the remote host.
    public func sendMessage(_ message: Message) throws {
        switch host {
        case .local(let weakReceiver):
            guard let receiver = weakReceiver.object else {
                throw MachError(0, "Registered local receiver is deallocated")
            }
            try withUnsafePointer(to: message) { messagePtr in
                try receiver.receiveLocalMessage(messagePtr)
            }
        case .remote(let port):
            try sendRemoteMessage(message, receiverPort: port)
        case .none:
            throw MachError(0, "No receiver found")
        }
    }
    
    /// Send a message to the remote host.
    private func sendRemoteMessage(_ message: Message, receiverPort: mach_port_t) throws {
        let dataSize = message.payloadCount
        let packetSize = MachPacketView.sizeWithoutData + dataSize
        let alignment = 8
        // align memory to 4 bytes
        let alignedPacketSize = alignMemory(size: packetSize, alignment: alignment)
        try withUnsafeTemporaryAllocation(byteCount: alignedPacketSize, alignment: 8) { buffer in
            guard let baseAddress = buffer.baseAddress else {
                throw MachError(10, "Failed to allocate memory")
            }
            let rawPointer = UnsafeMutableRawPointer(baseAddress)
            rawPointer.storeBytes(of: mach_msg_header_t(
                msgh_bits: mach_msg_copy_send_bits,
                msgh_size: mach_msg_size_t(alignedPacketSize),
                msgh_remote_port: receiverPort,
                msgh_local_port: mach_port_name_t(MACH_PORT_NULL),
                msgh_voucher_port: 0,
                msgh_id: 0
            ), as: mach_msg_header_t.self)
            
            rawPointer
                .advanced(by: MemoryLayout<MachPacketView>.offset(of: \.payloadSize)!)
                .storeBytes(of: Int64(dataSize), as: Int64.self)
            
            let payloadOffset = MachPacketView.sizeWithoutData
            try message.withPayloadBuffer { (src, count) in
                rawPointer.advanced(by: payloadOffset).copyMemory(from: src, byteCount: count)
            }
            
            let kr = mach_msg(
                rawPointer.assumingMemoryBound(to: mach_msg_header_t.self),
                MACH_SEND_MSG,
                mach_msg_size_t(alignedPacketSize),
                0,
                mach_port_name_t(MACH_PORT_NULL),
                MACH_MSG_TIMEOUT_NONE,
                mach_port_name_t(MACH_PORT_NULL)
            )
            guard kr == KERN_SUCCESS else {
                throw MachError(Int(kr), "Failed to send Mach message: \(kr)")
            }
            
            logger?.log(0, "Sent message to port \(String(describing: receiverPort))")
        }

    }
}


