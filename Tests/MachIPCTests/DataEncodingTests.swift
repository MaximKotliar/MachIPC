//
//  DataEncodingTests.swift
//  MachIPC
//
//  Created on 16.11.2025.
//

import XCTest
@testable import MachIPC

final class DataEncodingTests: XCTestCase {
    
    // MARK: - Data Tests
    
    func testDataMessageConvertible() throws {
        let originalData = Data([1, 2, 3, 4, 5])
        let message = Data(machPayload: originalData)
        XCTAssertEqual(message, originalData)
        XCTAssertEqual(message.machPayload, originalData)
    }
    
    func testDataPayloadProvider() {
        let data = Data([10, 20, 30, 40])
        let count = data.payloadCount
        XCTAssertEqual(count, 4)
        
        data.withPayloadBuffer { buffer, size in
            XCTAssertEqual(size, 4)
            let bytes = Array(UnsafeRawBufferPointer(start: buffer, count: size))
            XCTAssertEqual(bytes, [10, 20, 30, 40])
        }
    }
    
    func testDataFromBuffer() {
        let originalBytes: [UInt8] = [100, 200, 150, 75]
        let data = Data(originalBytes)
        
        // Test round-trip through buffer
        data.withPayloadBuffer { buffer, count in
            let reconstructed = Data(machPayloadBuffer: buffer, count: count)
            XCTAssertEqual(data, reconstructed)
        }
    }
    
    // MARK: - String Tests
    
    func testStringMessageConvertible() throws {
        let originalString = "Hello, Mach IPC!"
        let data = originalString.machPayload
        let reconstructed = String(machPayload: data)
        XCTAssertEqual(reconstructed, originalString)
    }
    
    func testStringFromBuffer() {
        let originalString = "Test String Encoding"
        let data = originalString.machPayload
        
        // Test round-trip through buffer
        data.withUnsafeBytes { bytes in
            guard let baseAddress = bytes.baseAddress else {
                XCTFail("Invalid buffer")
                return
            }
            let reconstructed = String(machPayloadBuffer: baseAddress, count: bytes.count)
            XCTAssertEqual(originalString, reconstructed)
        }
    }
    
    func testStringWithUnicode() throws {
        let unicodeString = "Hello 🌍 世界 مرحبا"
        let data = unicodeString.machPayload
        let reconstructed = String(machPayload: data)
        XCTAssertEqual(unicodeString, reconstructed)
    }
    
    // MARK: - Codable Tests
    
    func testCodableMessage() throws {
        struct TestMessage: Codable, Equatable, MachMessageConvertible {
            let id: Int
            let name: String
        }
        
        let original = TestMessage(id: 42, name: "Test")
        let data = original.machPayload
        let reconstructed = TestMessage(machPayload: data)
        
        XCTAssertEqual(original, reconstructed)
    }
    
    func testCodableComplexStructure() throws {
        struct ComplexMessage: Codable, Equatable, MachMessageConvertible {
            let id: Int
            let name: String
            let values: [Double]
            let metadata: [String: String]
        }
        
        let original = ComplexMessage(
            id: 123,
            name: "Complex",
            values: [1.5, 2.7, 3.14],
            metadata: ["key1": "value1", "key2": "value2"]
        )
        
        let data = original.machPayload
        let reconstructed = ComplexMessage(machPayload: data)
        
        XCTAssertEqual(original, reconstructed)
    }
    
    func testCodableFromBuffer() throws {
        struct TestMessage: Codable, Equatable, MachMessageConvertible {
            let id: Int
            let name: String
        }
        
        let original = TestMessage(id: 99, name: "Buffer Test")
        let data = original.machPayload
        
        // Test round-trip through buffer
        try data.withUnsafeBytes { bytes in
            guard let baseAddress = bytes.baseAddress else {
                XCTFail("Invalid buffer")
                return
            }
            let reconstructed = TestMessage(machPayloadBuffer: baseAddress, count: bytes.count)
            XCTAssertEqual(original, reconstructed)
        }
    }
    
    // MARK: - Payload Provider Tests
    
    func testPayloadCount() throws {
        let data = Data([1, 2, 3, 4, 5, 6, 7, 8, 9, 10])
        XCTAssertEqual(data.payloadCount, 10)
        
        let string = "Hello"
        XCTAssertGreaterThan(string.payloadCount, 0)
    }
    
    func testWithPayloadBuffer() throws {
        let data = Data([0xFF, 0x00, 0xAA, 0x55])
        
        var capturedBytes: [UInt8] = []
        try data.withPayloadBuffer { buffer, count in
            capturedBytes = Array(UnsafeRawBufferPointer(start: buffer, count: count))
        }
        
        XCTAssertEqual(capturedBytes, [0xFF, 0x00, 0xAA, 0x55])
    }
}

