//
//  MachError.swift
//  SubProcess
//
//  Created by Maxim Kotliar on 12.11.2025.
//

struct MachError: Swift.Error {
    let code: Int
    let message: String
    
    init(_ code: Int, _ message: String) {
        self.code = code
        self.message = message
    }
}
