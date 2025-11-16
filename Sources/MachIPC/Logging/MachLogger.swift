//
//  MachLogger.swift
//  SubProcess
//
//  Created by Maxim Kotliar on 12.11.2025.
//

public protocol Logger: AnyObject, Sendable {
    @inlinable func log(_ level: Int32, _ message: String)
}

