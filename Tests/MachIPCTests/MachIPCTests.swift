//
//  MachIPCTests.swift
//  MachIPC
//
//  Created on 16.11.2025.
//

import XCTest
@testable import MachIPC

final class MachIPCTests: XCTestCase {
    
    // MARK: - Basic Functionality Tests
    func testLocalMessagePassing() throws {
        var receivedMessage: String?
        let expectation = XCTestExpectation(description: "Message received")
        
        let endpoint = "com.test.local.\(UUID().uuidString)"
        
        let host = try MachHost<String>(
            endpoint: endpoint,
            onReceive: { message in
                receivedMessage = message
                expectation.fulfill()
            }
        )
        
        let client = try MachClient<String>(endpoint: endpoint)
        try client.sendMessage("Test message")
        
        wait(for: [expectation], timeout: 1.0)
        _ = host // Keep host alive
        XCTAssertEqual(receivedMessage, "Test message")
    }
    
    func testMultipleMessages() throws {
        var receivedMessages: [String] = []
        let expectation = XCTestExpectation(description: "All messages received")
        expectation.expectedFulfillmentCount = 5
        
        let endpoint = "com.test.multiple.\(UUID().uuidString)"
        
        let host = try MachHost<String>(
            endpoint: endpoint,
            onReceive: { message in
                receivedMessages.append(message)
                expectation.fulfill()
            }
        )
        
        let client = try MachClient<String>(endpoint: endpoint)
        
        let messages = ["First", "Second", "Third", "Fourth", "Fifth"]
        for message in messages {
            try client.sendMessage(message)
        }
        
        wait(for: [expectation], timeout: 2.0)
        _ = host // Keep host alive
        XCTAssertEqual(receivedMessages.sorted(), messages.sorted())
    }
    
    func testHostConfiguration() throws {
        var config = MachHostConfiguration.default
        config.logger = nil
        config.bufferSize = 1024 * 512
        config.logsThroughput = true
        config.highPerformanceModeThreshold = 150_000
        
        let endpoint = "com.test.config.\(UUID().uuidString)"
        
        let host = try MachHost<String>(
            endpoint: endpoint,
            configuration: config,
            onReceive: { _ in }
        )
        
        XCTAssertEqual(host.configuration.bufferSize, 1024 * 512)
        XCTAssertEqual(host.configuration.highPerformanceModeThreshold, 150_000)
    }
}

