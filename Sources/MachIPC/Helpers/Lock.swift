//
//  Lock.swift
//  SubProcess
//
//  Created by Maxim Kotliar on 13.11.2025.
//
import os.lock

public final class Lock {
    
    private let osLock: UnsafeMutablePointer<os_unfair_lock> = {
        let lock = UnsafeMutablePointer<os_unfair_lock>.allocate(capacity: 1)
        lock.initialize(to: .init())
        return lock
    }()
    
    public init() {}
    
    public func lock() {
        os_unfair_lock_lock(osLock)
    }
    
    public func unlock() {
        os_unfair_lock_unlock(osLock)
    }
    
    public func tryLock() -> Bool {
        return os_unfair_lock_trylock(osLock)
    }
    
    deinit {
        osLock.deinitialize(count: 1)
        osLock.deallocate()
    }
}
