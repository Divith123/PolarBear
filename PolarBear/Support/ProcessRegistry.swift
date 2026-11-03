//
//  ProcessRegistry.swift
//  PolarBear
//

import Darwin
import os

/// Remembers the child processes the app started, so quitting the app never leaves a
/// compiler or an agent running in the background.
nonisolated enum ProcessRegistry {
    private static let running = OSAllocatedUnfairLock(initialState: Set<pid_t>())

    static func add(_ pid: pid_t) {
        running.withLock { _ = $0.insert(pid) }
    }

    static func remove(_ pid: pid_t) {
        running.withLock { _ = $0.remove(pid) }
    }

    /// Stops every registered process and everything it started.
    static func terminateAll() {
        let pids = running.withLock { $0 }
        for pid in pids {
            for descendant in ProcessTree.descendants(of: pid) + [pid] {
                kill(descendant, SIGKILL)
            }
        }
    }
}
