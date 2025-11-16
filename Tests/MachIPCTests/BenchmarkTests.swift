//
//  BenchmarkTests.swift
//  MachIPC
//
//  Created on 16.11.2025.
//

import Foundation
import Darwin
import XCTest
@testable import MachIPC

final class BenchmarkTests: XCTestCase {
    
    // File-based lock to ensure benchmark tests run sequentially across processes
    private static let lockFileURL = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("com.machipc.benchmark.tests.lock")
    private static var lockFileHandle: FileHandle?
    
    override class func setUp() {
        super.setUp()
        // Ensure lock file exists
        if !FileManager.default.fileExists(atPath: lockFileURL.path) {
            FileManager.default.createFile(atPath: lockFileURL.path, contents: nil)
        }
    }
    
    override func setUp() {
        super.setUp()
        // Acquire file-based lock (works across processes)
        // This ensures only one benchmark test runs at a time
        var attempts = 0
        while Self.lockFileHandle == nil && attempts < 100 {
            do {
                let handle = try FileHandle(forWritingTo: Self.lockFileURL)
                if flock(handle.fileDescriptor, LOCK_EX | LOCK_NB) == 0 {
                    Self.lockFileHandle = handle
                    break
                }
                handle.closeFile()
            } catch {
                // Retry
            }
            Thread.sleep(forTimeInterval: 0.1)
            attempts += 1
        }
        
        if Self.lockFileHandle == nil {
            XCTFail("Failed to acquire benchmark test lock - another benchmark test may be running")
        }
    }
    
    override func tearDown() {
        // Release file lock
        if let handle = Self.lockFileHandle {
            flock(handle.fileDescriptor, LOCK_UN)
            handle.closeFile()
            Self.lockFileHandle = nil
        }
        Thread.sleep(forTimeInterval: 0.1) // Brief pause for cleanup
        super.tearDown()
    }
    
    // MARK: - Local Benchmarks
    
    func testLocalBenchmarkSmallMessages() throws {
        let endpoint = "com.benchmark.local.small.\(UUID().uuidString)"
        nonisolated(unsafe) var receivedCount = 0
        let totalMessages = 1_000_000
        
        let host = try MachHost<String>(
            endpoint: endpoint,
            configuration: {
                var config = MachHostConfiguration.default
                config.logger = nil
                config.logsThroughput = false
                return config
            }(),
            onReceive: { _ in
                receivedCount += 1
            }
        )
        
        let client = try MachClient<String>(endpoint: endpoint, logger: nil)
        
        let startTime = DispatchTime.now()
        
        for i in 0..<totalMessages {
            try client.sendMessage("msg-\(i)")
        }
        
        let sendEndTime = DispatchTime.now()
        let sendDuration = Double(sendEndTime.uptimeNanoseconds - startTime.uptimeNanoseconds) / 1_000_000_000.0
        
        // Wait for messages to be processed
        var waitCount = 0
        while receivedCount < totalMessages && waitCount < 100 {
            Thread.sleep(forTimeInterval: 0.1)
            waitCount += 1
        }
        
        let totalDuration = Double(DispatchTime.now().uptimeNanoseconds - startTime.uptimeNanoseconds) / 1_000_000_000.0
        let sendThroughput = Int(Double(totalMessages) / sendDuration)
        let totalThroughput = Int(Double(receivedCount) / totalDuration)
        
        print("=== Local Small Messages Benchmark ===")
        print("Messages sent: \(totalMessages)")
        print("Messages received: \(receivedCount)")
        print("Send throughput: \(sendThroughput) msg/s")
        print("Total throughput: \(totalThroughput) msg/s")
        print("Send duration: \(String(format: "%.3f", sendDuration))s")
        print("Total duration: \(String(format: "%.3f", totalDuration))s")
        _ = host
        XCTAssertGreaterThanOrEqual(receivedCount, totalMessages, "Should receive all messages")
    }
    
    func testLocalBenchmarkMediumMessages() throws {
        let endpoint = "com.benchmark.local.medium.\(UUID().uuidString)"
        var receivedCount = 0
        let totalMessages = 100_000
        let messageSize = 1024 // 1KB
        
        let testData = Data(repeating: 0x42, count: messageSize)
        
        let host = try MachHost<Data>(
            endpoint: endpoint,
            configuration: {
                var config = MachHostConfiguration.default
                config.logger = nil
                config.logsThroughput = false
                return config
            }(),
            onReceive: { data in
                XCTAssertEqual(data.count, messageSize)
                receivedCount += 1
            }
        )
        
        let client = try MachClient<Data>(endpoint: endpoint, logger: nil)
        
        let startTime = DispatchTime.now()
        
        for _ in 0..<totalMessages {
            try client.sendMessage(testData)
        }
        
        let sendEndTime = DispatchTime.now()
        let sendDuration = Double(sendEndTime.uptimeNanoseconds - startTime.uptimeNanoseconds) / 1_000_000_000.0
        
        var waitCount = 0
        while receivedCount < totalMessages && waitCount < 200 {
            Thread.sleep(forTimeInterval: 0.1)
            waitCount += 1
        }
        
        let totalDuration = Double(DispatchTime.now().uptimeNanoseconds - startTime.uptimeNanoseconds) / 1_000_000_000.0
        let sendThroughput = Int(Double(totalMessages) / sendDuration)
        let totalThroughput = Int(Double(receivedCount) / totalDuration)
        
        print("=== Local Medium Messages Benchmark ===")
        print("Messages: \(totalMessages), Size: \(messageSize) bytes each")
        print("Messages received: \(receivedCount)")
        print("Send throughput: \(sendThroughput) msg/s")
        print("Total throughput: \(totalThroughput) msg/s")
        print("Send duration: \(String(format: "%.3f", sendDuration))s")
        print("Total duration: \(String(format: "%.3f", totalDuration))s")
        
        XCTAssertGreaterThanOrEqual(receivedCount, totalMessages * 9 / 10)
        _ = host // Keep host alive
    }
    
    func testLocalBenchmarkLargeMessages() throws {
        let endpoint = "com.benchmark.local.large.\(UUID().uuidString)"
        nonisolated(unsafe)  var receivedCount = 0
        let totalMessages = 10_000
        let messageSize = 64 * 1024 // 64KB
        
        let testData = Data(repeating: 0xAA, count: messageSize)
        
        var config = MachHostConfiguration.default
        config.logger = nil
        config.logsThroughput = false
        config.bufferSize = 1024 * 1024 // 1MB buffer for large messages
        
        let host = try MachHost<Data>(
            endpoint: endpoint,
            configuration: config,
            onReceive: { data in
                XCTAssertEqual(data.count, messageSize)
                receivedCount += 1
            }
        )
        
        let client = try MachClient<Data>(endpoint: endpoint, logger: nil)
        
        let startTime = DispatchTime.now()
        
        for _ in 0..<totalMessages {
            try client.sendMessage(testData)
        }
        
        let sendEndTime = DispatchTime.now()
        let sendDuration = Double(sendEndTime.uptimeNanoseconds - startTime.uptimeNanoseconds) / 1_000_000_000.0
        
        var waitCount = 0
        while receivedCount < totalMessages && waitCount < 300 {
            Thread.sleep(forTimeInterval: 0.1)
            waitCount += 1
        }
        
        let totalDuration = Double(DispatchTime.now().uptimeNanoseconds - startTime.uptimeNanoseconds) / 1_000_000_000.0
        let sendThroughput = Int(Double(totalMessages) / sendDuration)
        let totalThroughput = Int(Double(receivedCount) / totalDuration)
        let dataRate = Double(receivedCount * messageSize) / totalDuration / 1_000_000.0 // MB/s
        
        print("=== Local Large Messages Benchmark ===")
        print("Messages: \(totalMessages), Size: \(messageSize) bytes each")
        print("Messages received: \(receivedCount)")
        print("Send throughput: \(sendThroughput) msg/s")
        print("Total throughput: \(totalThroughput) msg/s")
        print("Data rate: \(String(format: "%.2f", dataRate)) MB/s")
        print("Send duration: \(String(format: "%.3f", sendDuration))s")
        print("Total duration: \(String(format: "%.3f", totalDuration))s")
        
        XCTAssertGreaterThanOrEqual(receivedCount, totalMessages)
        _ = host // Keep host alive
    }
    
    func testLocalBenchmarkVeryLargeMessages() throws {
        let endpoint = "com.benchmark.local.verylarge.\(UUID().uuidString)"
        nonisolated(unsafe) var receivedCount = 0
        let totalMessages = 1000
        let messageSize = 10 * 1024 * 1024 // 10MB
        
        let testData = Data(repeating: 0xCC, count: messageSize)
        
        var config = MachHostConfiguration.default
        config.logger = nil
        config.logsThroughput = false
        config.bufferSize = 12 * 1024 * 1024 // 12MB buffer for 10MB messages
        
        let host = try MachHost<Data>(
            endpoint: endpoint,
            configuration: config,
            onReceive: { data in
                XCTAssertEqual(data.count, messageSize)
                receivedCount += 1
            }
        )
        
        let client = try MachClient<Data>(endpoint: endpoint, logger: nil)
        
        let startTime = DispatchTime.now()
        
        for _ in 0..<totalMessages {
            try client.sendMessage(testData)
        }
        
        let sendEndTime = DispatchTime.now()
        let sendDuration = Double(sendEndTime.uptimeNanoseconds - startTime.uptimeNanoseconds) / 1_000_000_000.0
        
        var waitCount = 0
        while receivedCount < totalMessages && waitCount < 600 {
            Thread.sleep(forTimeInterval: 0.1)
            waitCount += 1
        }
        
        let totalDuration = Double(DispatchTime.now().uptimeNanoseconds - startTime.uptimeNanoseconds) / 1_000_000_000.0
        let sendThroughput = Int(Double(totalMessages) / sendDuration)
        let totalThroughput = Int(Double(receivedCount) / totalDuration)
        let dataRate = Double(receivedCount * messageSize) / totalDuration / 1_000_000.0 // MB/s
        let totalDataMB = Double(totalMessages * messageSize) / 1_000_000.0
        
        print("=== Local Very Large Messages (10MB) Benchmark ===")
        print("Messages: \(totalMessages), Size: \(messageSize / 1024 / 1024)MB each")
        print("Total data: \(String(format: "%.2f", totalDataMB)) MB")
        print("Messages received: \(receivedCount)")
        print("Send throughput: \(sendThroughput) msg/s")
        print("Total throughput: \(totalThroughput) msg/s")
        print("Data rate: \(String(format: "%.2f", dataRate)) MB/s")
        print("Send duration: \(String(format: "%.3f", sendDuration))s")
        print("Total duration: \(String(format: "%.3f", totalDuration))s")
        
        XCTAssertGreaterThanOrEqual(receivedCount, totalMessages)
        _ = host // Keep host alive
    }
    
    // MARK: - Remote Benchmarks
    
    func testRemoteBenchmarkSmallMessages() throws {
        let endpoint = "com.benchmark.remote.small.\(UUID().uuidString)"
        nonisolated(unsafe) var receivedCount = 0
        let totalMessages = 500_000
        
        MachLocalhostRegistry.shared.isLookupEnabled = false
        defer {
            MachLocalhostRegistry.shared.isLookupEnabled = true
        }
        
        let host = try MachHost<String>(
            endpoint: endpoint,
            configuration: {
                var config = MachHostConfiguration.default
                config.logger = nil
                config.logsThroughput = false
                return config
            }(),
            onReceive: { _ in
                receivedCount += 1
            }
        )
        
        Thread.sleep(forTimeInterval: 0.1)
        
        let client = try MachClient<String>(endpoint: endpoint, logger: nil)
        
        let startTime = DispatchTime.now()
        
        for i in 0..<totalMessages {
            try client.sendMessage("remote-msg-\(i)")
        }
        
        let sendEndTime = DispatchTime.now()
        let sendDuration = Double(sendEndTime.uptimeNanoseconds - startTime.uptimeNanoseconds) / 1_000_000_000.0
        
        var waitCount = 0
        while receivedCount < totalMessages && waitCount < 200 {
            Thread.sleep(forTimeInterval: 0.1)
            waitCount += 1
        }
        
        let totalDuration = Double(DispatchTime.now().uptimeNanoseconds - startTime.uptimeNanoseconds) / 1_000_000_000.0
        let sendThroughput = Int(Double(totalMessages) / sendDuration)
        let totalThroughput = Int(Double(receivedCount) / totalDuration)
        
        print("=== Remote Small Messages Benchmark ===")
        print("Messages sent: \(totalMessages)")
        print("Messages received: \(receivedCount)")
        print("Send throughput: \(sendThroughput) msg/s")
        print("Total throughput: \(totalThroughput) msg/s")
        print("Send duration: \(String(format: "%.3f", sendDuration))s")
        print("Total duration: \(String(format: "%.3f", totalDuration))s")
        
        XCTAssertGreaterThanOrEqual(receivedCount, totalMessages)
        _ = host // Keep host alive
    }
    
    func testRemoteBenchmarkVeryLargeMessages() throws {
        let endpoint = "com.benchmark.remote.verylarge.\(UUID().uuidString)"
        nonisolated(unsafe) var receivedCount = 0
        let totalMessages = 1000
        let messageSize = 10 * 1024 * 1024 // 10MB
        
        let testData = Data(repeating: 0xDD, count: messageSize)
        
        MachLocalhostRegistry.shared.isLookupEnabled = false
        defer {
            MachLocalhostRegistry.shared.isLookupEnabled = true
        }
        
        var config = MachHostConfiguration.default
        config.logger = nil
        config.logsThroughput = false
        config.bufferSize = 12 * 1024 * 1024 // 12MB buffer for 10MB messages
        
        let host = try MachHost<Data>(
            endpoint: endpoint,
            configuration: config,
            onReceive: { data in
                XCTAssertEqual(data.count, messageSize)
                receivedCount += 1
            }
        )
        
        Thread.sleep(forTimeInterval: 0.1)
        
        let client = try MachClient<Data>(endpoint: endpoint, logger: nil)
        
        let startTime = DispatchTime.now()
        
        for _ in 0..<totalMessages {
            try client.sendMessage(testData)
        }
        
        let sendEndTime = DispatchTime.now()
        let sendDuration = Double(sendEndTime.uptimeNanoseconds - startTime.uptimeNanoseconds) / 1_000_000_000.0
        
        var waitCount = 0
        while receivedCount < totalMessages && waitCount < 600 {
            Thread.sleep(forTimeInterval: 0.1)
            waitCount += 1
        }
        
        let totalDuration = Double(DispatchTime.now().uptimeNanoseconds - startTime.uptimeNanoseconds) / 1_000_000_000.0
        let sendThroughput = Int(Double(totalMessages) / sendDuration)
        let totalThroughput = Int(Double(receivedCount) / totalDuration)
        let dataRate = Double(receivedCount * messageSize) / totalDuration / 1_000_000.0 // MB/s
        let totalDataMB = Double(totalMessages * messageSize) / 1_000_000.0
        
        print("=== Remote Very Large Messages (10MB) Benchmark ===")
        print("Messages: \(totalMessages), Size: \(messageSize / 1024 / 1024)MB each")
        print("Total data: \(String(format: "%.2f", totalDataMB)) MB")
        print("Messages received: \(receivedCount)")
        print("Send throughput: \(sendThroughput) msg/s")
        print("Total throughput: \(totalThroughput) msg/s")
        print("Data rate: \(String(format: "%.2f", dataRate)) MB/s")
        print("Send duration: \(String(format: "%.3f", sendDuration))s")
        print("Total duration: \(String(format: "%.3f", totalDuration))s")
        
        XCTAssertGreaterThanOrEqual(receivedCount, totalMessages)
        _ = host // Keep host alive
    }
}

