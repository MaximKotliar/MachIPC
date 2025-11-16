//
//  EventSpeedMeasurement.swift
//  MachIPC
//
//  Created by Maxim Kotliar on 16.11.2025.
//

import Dispatch

struct EventSpeedMeasurement {
    private var timestamp: DispatchTime?
    private var eventsCount: Int = 0

    mutating func trackEvent(count: Int = 1) {
        eventsCount += count
    }

    mutating func collectMeasurement() -> Int? {
        guard let lastTime = timestamp else {
            timestamp = .now()
            return nil
        }
        let now = DispatchTime.now()
        let elapsed = now.uptimeNanoseconds - lastTime.uptimeNanoseconds
        if elapsed > NSEC_PER_SEC {
            let throughput = eventsCount
            timestamp = DispatchTime.now()
            eventsCount = 0
            return throughput
        }
        return nil
    }
}
