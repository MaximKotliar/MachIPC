//
//  ThroughputTests.swift
//  MachIPC
//
//  Created on 16.11.2025.
//

import Foundation
import Darwin
import XCTest
@testable import MachIPC

final class ThroughputTests: XCTestCase {
    
    // File-based lock to ensure throughput tests run sequentially across processes
    private static let lockFileURL = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("com.machipc.throughput.tests.lock")
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
        // This ensures only one throughput test runs at a time
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
            XCTFail("Failed to acquire test lock - another throughput test may be running")
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
    
    // MARK: - Local Throughput Tests
    
    func testLocalThroughput() throws {
        var messageCount = 0
        let totalMessages = 100_000
        let expectation = XCTestExpectation(description: "All messages received")
        expectation.expectedFulfillmentCount = totalMessages
        
        let endpoint = "com.test.local.throughput.\(UUID().uuidString)"
        
        let host = try MachHost<String>(
            endpoint: endpoint,
            configuration: {
                var config = MachHostConfiguration.default
                config.logger = nil // Disable logging for performance
                config.logsThroughput = false
                return config
            }(),
            onReceive: { _ in
                messageCount += 1
                expectation.fulfill()
            }
        )
        
        let client = try MachClient<String>(endpoint: endpoint, logger: nil)
        
        let startTime = DispatchTime.now()
        
        // Send all messages
        for i in 0..<totalMessages {
            try client.sendMessage("Message \(i)")
        }
        
        wait(for: [expectation], timeout: 10.0)
        
        let endTime = DispatchTime.now()
        let duration = Double(endTime.uptimeNanoseconds - startTime.uptimeNanoseconds) / 1_000_000_000.0
        let throughput = Double(messageCount) / duration
        
        print("Local throughput: \(Int(throughput)) messages/second")
        print("Total messages: \(messageCount), Duration: \(String(format: "%.3f", duration))s")
        
        XCTAssertEqual(messageCount, totalMessages, "All messages should be received")
        XCTAssertGreaterThan(throughput, 100_000, "Should achieve at least 100k messages/second locally")
        _ = host // Keep host alive
    }
    
    func testLocalThroughputWithData() throws {
        var messageCount = 0
        let totalMessages = 50_000
        let messageSize = 1024 // 1KB per message
        let testData = Data(repeating: 0xAA, count: messageSize)
        
        let expectation = XCTestExpectation(description: "All messages received")
        expectation.expectedFulfillmentCount = totalMessages
        
        let endpoint = "com.test.local.data.\(UUID().uuidString)"
        
        let host = try MachHost<Data>(
            endpoint: endpoint,
            configuration: {
                var config = MachHostConfiguration.default
                config.logger = nil
                config.logsThroughput = false
                return config
            }(),
            onReceive: { receivedData in
                XCTAssertEqual(receivedData.count, messageSize)
                messageCount += 1
                expectation.fulfill()
            }
        )
        
        let client = try MachClient<Data>(endpoint: endpoint, logger: nil)
        
        let startTime = DispatchTime.now()
        
        for _ in 0..<totalMessages {
            try client.sendMessage(testData)
        }
        
        wait(for: [expectation], timeout: 15.0)
        
        let endTime = DispatchTime.now()
        let duration = Double(endTime.uptimeNanoseconds - startTime.uptimeNanoseconds) / 1_000_000_000.0
        let throughput = Double(messageCount) / duration
        
        print("Local data throughput: \(Int(throughput)) messages/second")
        print("Message size: \(messageSize) bytes, Total: \(messageCount) messages")
        
        XCTAssertEqual(messageCount, totalMessages)
        XCTAssertGreaterThan(throughput, 10_000, "Should achieve at least 10k messages/second with 1KB data")
        _ = host // Keep host alive
    }
    
    // MARK: - Remote Throughput Tests (within same process)
    func testRemoteThroughput() throws {
        var messageCount = 0
        let totalMessages = 500_000
        let expectedThroughput = 200_000
        let expectation = XCTestExpectation(description: "All messages received")
        expectation.expectedFulfillmentCount = totalMessages
        
        let endpoint = "com.test.remote.throughput.\(UUID().uuidString)"
        
        // Disable local registry to force remote communication
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
                messageCount += 1
                expectation.fulfill()
            }
        )
        
        // Give host time to register
        Thread.sleep(forTimeInterval: 0.1)
        
        let client = try MachClient<String>(endpoint: endpoint, logger: nil)
        
        let startTime = DispatchTime.now()
        
        for i in 0..<totalMessages {
            try client.sendMessage("Remote message \(i)")
        }
        
        wait(for: [expectation], timeout: 15.0)
        
        let endTime = DispatchTime.now()
        let duration = Double(endTime.uptimeNanoseconds - startTime.uptimeNanoseconds) / 1_000_000_000.0
        let throughput = Double(messageCount) / duration
        
        print("Remote throughput: \(Int(throughput)) messages/second")
        print("Total messages: \(messageCount), Duration: \(String(format: "%.3f", duration))s")
        
        XCTAssertEqual(messageCount, totalMessages)
        XCTAssertGreaterThan(Int(throughput), expectedThroughput, "Should achieve at least \(expectedThroughput) messages/second remotely")
        _ = host // Keep host alive
    }
    
    func testRemoteThroughputWithData() throws {
        var messageCount = 0
        let totalMessages = 25_000
        let messageSize = 512 // 512 bytes per message
        let testData = Data(repeating: 0xBB, count: messageSize)
        
        let expectation = XCTestExpectation(description: "All messages received")
        expectation.expectedFulfillmentCount = totalMessages
        
        let endpoint = "com.test.remote.data.\(UUID().uuidString)"
        
        MachLocalhostRegistry.shared.isLookupEnabled = false
        defer {
            MachLocalhostRegistry.shared.isLookupEnabled = true
        }
        
        let host = try MachHost<Data>(
            endpoint: endpoint,
            configuration: {
                var config = MachHostConfiguration.default
                config.logger = nil
                config.logsThroughput = false
                return config
            }(),
            onReceive: { receivedData in
                XCTAssertEqual(receivedData.count, messageSize)
                messageCount += 1
                expectation.fulfill()
            }
        )
        
        Thread.sleep(forTimeInterval: 0.1)
        
        let client = try MachClient<Data>(endpoint: endpoint, logger: nil)
        
        let startTime = DispatchTime.now()
        
        for _ in 0..<totalMessages {
            try client.sendMessage(testData)
        }
        
        wait(for: [expectation], timeout: 20.0)
        
        let endTime = DispatchTime.now()
        let duration = Double(endTime.uptimeNanoseconds - startTime.uptimeNanoseconds) / 1_000_000_000.0
        let throughput = Double(messageCount) / duration
        
        print("Remote data throughput: \(Int(throughput)) messages/second")
        print("Message size: \(messageSize) bytes, Total: \(messageCount) messages")
        
        XCTAssertEqual(messageCount, totalMessages)
        XCTAssertGreaterThan(throughput, 5_000, "Should achieve at least 5k messages/second remotely with data")
        _ = host // Keep host alive
    }
    
    // MARK: - Latency Tests
    
    func testLocalLatency() throws {
        var latencies: [TimeInterval] = []
        let iterations = 10_000
        
        let endpoint = "com.test.latency.\(UUID().uuidString)"
        
        let host = try MachHost<String>(
            endpoint: endpoint,
            configuration: {
                var config = MachHostConfiguration.default
                config.logger = nil
                return config
            }(),
            onReceive: { message in
                if message.starts(with: "latency") {
                    let endTime = DispatchTime.now()
                    let components = message.split(separator: ":")
                    if components.count == 2,
                       let startNanoseconds = UInt64(components[1]) {
                        let latency = Double(endTime.uptimeNanoseconds - startNanoseconds) / 1_000_000.0 // Convert to milliseconds
                        latencies.append(latency)
                    }
                }
            }
        )
        
        let client = try MachClient<String>(endpoint: endpoint, logger: nil)
        
        for _ in 0..<iterations {
            let startTime = DispatchTime.now()
            try client.sendMessage("latency:\(startTime.uptimeNanoseconds)")
            Thread.sleep(forTimeInterval: 0.0001) // Small delay to avoid overwhelming
        }
        
        Thread.sleep(forTimeInterval: 1.0) // Wait for all messages
        
        guard !latencies.isEmpty else {
            XCTFail("No latency measurements received")
            return
        }
        
        let avgLatency = latencies.reduce(0, +) / Double(latencies.count)
        let minLatency = latencies.min() ?? 0
        let maxLatency = latencies.max() ?? 0
        
        print("Local latency - Avg: \(String(format: "%.3f", avgLatency))μs, Min: \(String(format: "%.3f", minLatency))μs, Max: \(String(format: "%.3f", maxLatency))μs")
        
        XCTAssertLessThan(avgLatency, 10.0, "Average latency should be less than 10μs locally")
    }
}

