//
//  ConsoleLogger.swift
//  MachIPC
//
//  Created by Maxim Kotliar on 16.11.2025.
//

public final class ConsoleLogger: Logger {
    @inline(__always)
    public func log(_ level: Int32, _ message: String) {
        print(message)
    }
}
