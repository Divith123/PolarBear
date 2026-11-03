//
//  Debouncer.swift
//  PolarBear
//

import Foundation

/// Runs the last scheduled action once `delay` has passed without another `schedule` call.
final class Debouncer {
    private var task: Task<Void, Never>?

    func schedule(after delay: Duration, _ action: @escaping () async -> Void) {
        task?.cancel()
        task = Task {
            do {
                try await Task.sleep(for: delay)
            } catch {
                return // Replaced by a newer call, or cancelled.
            }
            await action()
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
    }

    isolated deinit {
        task?.cancel()
    }
}
