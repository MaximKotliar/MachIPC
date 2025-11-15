//
//  MachHost.swift
//  SubProcess
//
//  Created by Maxim Kotliar on 12.11.2025.
//

import Foundation
import Darwin

public final class MachHost<Message: MachMessageConvertible>: Sendable {
    
    private let source: DispatchSourceMachReceive
    public let endpoint: String
    public let port: mach_port_t
    public let logger: Logger?
    nonisolated(unsafe) public var callback: ((Message) -> Void)?
    
    public init(endpoint: String, logger: Logger? = nil) throws {
        self.logger = logger
        self.endpoint = endpoint
        self.port = try Self.registerEndpoint(withName: endpoint, logger: logger)
        self.source = DispatchSource.makeMachReceiveSource(port: port)
        self.setupMachReceiveSource()
        MachLocalhostRegistry.shared.register(host: self)
    }
    
    internal func receiveLocalMessage(_ ptr: UnsafeRawPointer) throws {
        callback?(ptr.load(as: Message.self))
    }
    
    private func setupMachReceiveSource() {
        let opBufferSize = 1024 * 256
        let opBuffer = UnsafeMutableRawPointer.allocate(byteCount: opBufferSize, alignment: 8)
        source.setEventHandler { [weak self] in
            guard let self else { return }
            self.receiveRemoteMessage(into: opBuffer, ofSize: opBufferSize)
        }
        source.resume()
    }
    
    private func receiveRemoteMessage(into buffer: UnsafeMutableRawPointer,
                                      ofSize bufferSize: Int) {
        var kr: Int32 = -1
        kr = buffer.withMemoryRebound(to: mach_msg_header_t.self, capacity: 1) { pointer in
            mach_msg_overwrite(pointer,
                               MACH_RCV_MSG | MACH_RCV_OVERWRITE | MACH_RCV_TIMEOUT,
                               0,
                               mach_msg_size_t(bufferSize),
                               port,
                               0,
                               mach_port_name_t(MACH_PORT_NULL),
                               pointer,
                               mach_msg_size_t(bufferSize))
        }
        
        switch kr {
        case KERN_SUCCESS:
            let packet = buffer.assumingMemoryBound(to: MachPacketView.self)
            let payload = Data(bytes: buffer.advanced(by: MemoryLayout<MachPacketView>.size), count: Int(packet.pointee.payloadSize))
            let message = Message(machPayload: payload)
            callback?(message)
        case MACH_RCV_TIMED_OUT:
            break
        default:
            logger?.log(5, "mach_msg error: \(kr)")
        }
    }
}

// MARK: Setup mach host
extension MachHost {
    
    private static func registerEndpoint(withName endpointName: String, logger: Logger?) throws -> mach_port_t {
        var receivePort: mach_port_t = 0
        let kr = bootstrap_check_in(bootstrap_port, endpointName, &receivePort)
        guard kr == KERN_SUCCESS else {
            throw MachError(Int(kr), "Error while bootstrapping port")
        }
        
        // Insert send right for the port
        mach_port_insert_right(mach_task_self_, receivePort, receivePort, mach_msg_type_name_t(MACH_MSG_TYPE_MAKE_SEND))
        logger?.log(1, "Host port created: \(receivePort)")
        return receivePort
    }
}
