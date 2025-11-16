//
//  MachMessage.swift
//  SubProcess
//
//  Created by Maxim Kotliar on 12.11.2025.
//

import Foundation

// MARK: - Lowest Level: Raw Buffer Access
/// Lowest level protocol that allows providing payload buffer and count
public protocol MachPayloadProvider: Sendable {
    /// Initialize from raw payload buffer
    init(machPayloadBuffer: UnsafeRawPointer, count: Int)
    /// Provides access to the raw payload buffer and its byte count
    func withPayloadBuffer<T>(_ body: (UnsafeRawPointer, Int) throws -> T) rethrows -> T
    /// The number of bytes in the payload
    var payloadCount: Int { get }
}

// MARK: - Data Level: Data-based Messages
public protocol MachMessageConvertible: MachPayloadProvider {
    init(machPayload: Data)
    var machPayload: Data { get }
}

extension MachMessageConvertible {
    public init(machPayloadBuffer: UnsafeRawPointer, count: Int) {
        let data = Data(bytes: machPayloadBuffer, count: count)
        self.init(machPayload: data)
    }
    
    public func withPayloadBuffer<T>(_ body: (UnsafeRawPointer, Int) throws -> T) rethrows -> T {
        return try machPayload.withUnsafeBytes { bytes in
            guard let baseAddress = bytes.baseAddress else {
                throw MachError(0, "Invalid payload buffer")
            }
            return try body(baseAddress, bytes.count)
        }
    }
    
    public var payloadCount: Int {
        machPayload.count
    }
}

extension Data: MachMessageConvertible {
    public init(machPayload: Data) {
        self = machPayload
    }
    public var machPayload: Data { self }
}
extension String: MachMessageConvertible {}

// MARK: - Codable Support

/// All Codable types can automatically work with MachMessageConvertible via Data
extension MachMessageConvertible where Self: Codable {
    public init(machPayload: Data) {
        let decoder = JSONDecoder()
        self = try! decoder.decode(Self.self, from: machPayload)
    }
    
    public var machPayload: Data {
        let encoder = JSONEncoder()
        return try! encoder.encode(self)
    }
}
