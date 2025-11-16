//
//  MachHostConfiguration.swift
//  MachIPC
//
//  Created by Maxim Kotliar on 16.11.2025.
//


public struct MachHostConfiguration {
    public var logger: Logger? = ConsoleLogger()
    // buffer size for receiving messages, you can increase it if you need to receive larger messages
    public var bufferSize = 1024 * 256 // 256kb
    // log throughput every second
    public var logsThroughput = false
    // switch to high performance (no-wait) mode after reaching this speed (messages per second)
    public var highPerformanceModeThreshold: Int = 200_000
    // Thread priority for receiver thread (0 = normal, higher = higher priority, range typically -127 to 127)
    // Higher priority can reduce latency but may impact other threads. Default: 0 (normal priority)
    public var threadPriority: Int32 = 0

    public static let `default` = MachHostConfiguration()
}
