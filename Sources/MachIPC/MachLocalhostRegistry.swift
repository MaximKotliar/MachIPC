//
//  MachLocalHostRegistry.swift
//  SubProcess
//
//  Created by Maxim Kotliar on 14.11.2025.
//

final class MachLocalhostRegistry: @unchecked Sendable {
    
    private init() {}
    static let shared = MachLocalhostRegistry()

    private let lock = Lock()
    private var activeEndpoints: [String: Weak<AnyObject>] = [:]
    private var _isLookupEnabled: Bool = true
}

// MARK: - Receiver registration
extension MachLocalhostRegistry {
    
    func register<Message>(host: MachHost<Message>) {
        lock.lock()
        defer { lock.unlock() }
        activeEndpoints[host.endpoint] = Weak(host)
    }
    
    func unregisterHost(for endpoint: String) {
        lock.lock()
        defer { lock.unlock() }
        activeEndpoints[endpoint] = nil
    }
}

// MARK: - Receiver lookup
extension MachLocalhostRegistry {
    
    public var isLookupEnabled: Bool {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _isLookupEnabled
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _isLookupEnabled = newValue
        }
    }
    
    func localReceiver<Message>(for endpoint: String) -> MachHost<Message>? {
        lock.lock()
        defer { lock.unlock() }
        guard _isLookupEnabled else { return nil }
        return activeEndpoints[endpoint]?.object as? MachHost<Message>
    }
}
