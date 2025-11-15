//
//  MachMessage.swift
//  SubProcess
//
//  Created by Maxim Kotliar on 12.11.2025.
//

import Foundation

public protocol MachMessageConvertible: Sendable {
    init(machPayload: Data)
    var machPayload: Data { get }
}

extension Data: MachMessageConvertible {
    public init(machPayload: Data) {
        self = machPayload
    }
    public var machPayload: Data { self }
}

extension String: MachMessageConvertible {
    
    public init(machPayload: Data) {
        self.init(data: machPayload, encoding: .utf8)!
    }
    public var machPayload: Data { self.data(using: .utf8) ?? Data() }
}
