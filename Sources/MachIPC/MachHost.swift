//
//  MachHost.swift
//  SubProcess
//
//  Created by Maxim Kotliar on 12.11.2025.
//

import Foundation
import Darwin



public final class MachHost<Message: MachPayloadProvider>: Sendable {
    
    public let endpoint: String
    public let port: mach_port_t
    public let configuration: MachHostConfiguration

    private var logger: Logger? { configuration.logger }
    private let onReceive: (@Sendable (Message) -> Void)?
    nonisolated(unsafe) private var highPerformanceMode = false
    
    nonisolated(unsafe) private var localThroughputMeasurement = EventSpeedMeasurement()
    
    public init(endpoint: String, configuration: MachHostConfiguration = .default, onReceive: @Sendable @escaping (Message) -> Void) throws {
        self.configuration = configuration
        self.endpoint = endpoint
        self.port = try Self.registerEndpoint(withName: endpoint, logger: configuration.logger)
        self.onReceive = onReceive
        self.setupReceiverThread()
        MachLocalhostRegistry.shared.register(host: self)
    }
    
    internal func receiveLocalMessage(_ message: Message) throws {
        if configuration.logsThroughput {
            localThroughputMeasurement.trackEvent()
            if let throughput = localThroughputMeasurement.collectMeasurement() {
                logger?.log(0, " local messages throughput: \(throughput) per second")
            }
        }
        onReceive?(message)
    }
    
    private func setupReceiverThread() {
        let opBufferSize = configuration.bufferSize
        let opBuffer = UnsafeMutableRawPointer.allocate(byteCount: opBufferSize, alignment: 8)
        
        var speedMeasurement = EventSpeedMeasurement()
        let threadPriority = configuration.threadPriority
        let thread = Thread { [weak self] in
            // Set thread priority if configured
            if threadPriority != 0 {
                Thread.setCurrentThreadPriority(threadPriority, logger: self?.logger)
            }
            
            while let self {
                if self.receiveRemoteMessage(into: opBuffer, ofSize: opBufferSize) {
                    speedMeasurement.trackEvent()
                }
                if let throughput = speedMeasurement.collectMeasurement() {
                    if configuration.logsThroughput {
                        logger?.log(0, "remote messages throughput: \(throughput) per second")
                    }
                    self.highPerformanceMode = throughput > configuration.highPerformanceModeThreshold
                }
            }
        }
        thread.name = "com.mach-ipc.host-receive"
        thread.start()
    }

    
    private func receiveRemoteMessage(into buffer: UnsafeMutableRawPointer,
                                      ofSize bufferSize: Int) -> Bool {
        var kr: Int32 = -1
        let timeout = highPerformanceMode ? 0 : MachHostConstants.idleReceiverThreadTimeout
        kr = buffer.withMemoryRebound(to: mach_msg_header_t.self, capacity: 1) { pointer in
            mach_msg_overwrite(pointer,
                               MACH_RCV_MSG | MACH_RCV_OVERWRITE | MACH_RCV_TIMEOUT,
                               0,
                               mach_msg_size_t(bufferSize),
                               port,
                               timeout,
                               mach_port_name_t(MACH_PORT_NULL),
                               pointer,
                               mach_msg_size_t(bufferSize))
        }
        
        switch kr {
        case KERN_SUCCESS:
            let packet = buffer.assumingMemoryBound(to: MachPacketView.self)
            let payloadOffset = MemoryLayout<MachPacketView>.size
            let payloadBuffer = buffer.advanced(by: payloadOffset)
            let payloadSize = Int(packet.pointee.payloadSize)
            let message = Message(machPayloadBuffer: payloadBuffer, count: payloadSize)
            self.onReceive?(message)
            return true
        case MACH_RCV_TIMED_OUT:
            break
        default:
            logger?.log(5, "mach_msg error: \(kr)")
        }
        return false
    }
}

// MARK: Setup mach host
extension MachHost {
    

    private static func registerEndpoint(withName endpointName: String, logger: Logger?) throws -> mach_port_t {
        var receivePort: mach_port_t = 0
        let kr = bootstrap_check_in(bootstrap_port, endpointName, &receivePort)
        guard kr == KERN_SUCCESS else {
            let message = switch kr {
            case 1100:
                "Error while bootstrapping port: service with same endpoint name is already registered"
            default:
                "Error while bootstrapping port"
            }
            throw MachError(Int(kr), message)
        }
        
        // Insert send right for the port
        mach_port_insert_right(mach_task_self_, receivePort, receivePort, mach_msg_type_name_t(MACH_MSG_TYPE_MAKE_SEND))
        logger?.log(1, "Host port created: \(receivePort)")
        return receivePort
    }
}
