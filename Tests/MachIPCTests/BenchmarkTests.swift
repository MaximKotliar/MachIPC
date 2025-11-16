//
//  BenchmarkTests.swift
//  MachIPC
//
//  Created on 16.11.2025.
//

import XCTest
@testable import MachIPC

final class BenchmarkTests: XCTestCase {
    
    // MARK: - Local Benchmarks
    
    func testLocalBenchmarkSmallMessages() throws {
        let endpoint = "com.benchmark.local.small.\(UUID().uuidString)"
        var receivedCount = 0
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
        
        XCTAssertGreaterThanOrEqual(receivedCount, totalMessages * 9 / 10, "Should receive at least 90% of messages")
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
    }
    
    func testLocalBenchmarkLargeMessages() throws {
        let endpoint = "com.benchmark.local.large.\(UUID().uuidString)"
        var receivedCount = 0
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
        
        XCTAssertGreaterThanOrEqual(receivedCount, totalMessages * 9 / 10)
    }
    
    // MARK: - Remote Benchmarks
    
    func testRemoteBenchmarkSmallMessages() throws {
        let endpoint = "com.benchmark.remote.small.\(UUID().uuidString)"
        var receivedCount = 0
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
        
        XCTAssertGreaterThanOrEqual(receivedCount, totalMessages * 9 / 10)
    }
}

