//
//  ThrreadPriority.swift
//  MachIPC
//
//  Created by Maxim Kotliar on 16.11.2025.
//

import Foundation
import Darwin.Mach

extension Thread {
    static func setCurrentThreadPriority(_ priority: Int32, logger: Logger?) {
        let thread = mach_thread_self()
        defer { mach_port_deallocate(mach_task_self_, thread) }
        
        // thread_precedence_policy_data_t structure: { integer_t importance; }
        var policy: [integer_t] = [integer_t(priority)]
        let kr = thread_policy_set(
            thread,
            thread_policy_flavor_t(THREAD_PRECEDENCE_POLICY),
            &policy,
            mach_msg_type_number_t(1)
        )
        
        if kr != KERN_SUCCESS {
            logger?.log(2, "Failed to set thread priority to: \(priority)")
        }
    }
}
