//
//  Weak.swift
//  SubProcess
//
//  Created by Maxim Kotliar on 14.11.2025.
//

struct Weak<Object: AnyObject> {
    internal init(_ object: Object?) {
        self.object = object
    }
    weak var object: Object?
}
