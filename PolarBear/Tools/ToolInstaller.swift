//
//  ToolInstaller.swift
//  PolarBear
//

import Foundation
import Observation

/// Installs and removes the tools PolarBear can fetch for the user. Nothing is downloaded until the
/// user presses an install button.
@Observable
final class ToolInstaller {
    private(set) var states: [ManagedTool: ToolInstallState] = [:]
    @ObservationIgnored private var tasks: [ManagedTool: Task<Void, Never>] = [:]

    func state(for tool: ManagedTool) -> ToolInstallState {
        states[tool] ?? .idle
    }

    func isInstalling(_ tool: ManagedTool) -> Bool {
        if case .working = state(for: tool) { true } else { false }
    }

    /// Installs `tool`; `finished` runs afterwards on success (to look for the new program).
    func install(_ tool: ManagedTool, finished: @escaping () async -> Void) {
        guard !isInstalling(tool) else { return }
        states[tool] = .working(step: String(localized: "Looking up the latest version…"), fraction: nil)

        let (steps, continuation) = AsyncStream<ToolInstallation.Step>.makeStream(bufferingPolicy: .bufferingNewest(1))
        tasks[tool] = Task { [weak self] in
            async let outcome: Result<URL, Error> = {
                defer { continuation.finish() }
                do {
                    return .success(try await ToolInstallation.run(tool) { continuation.yield($0) })
                } catch {
                    return .failure(error)
                }
            }()
            for await step in steps {
                self?.states[tool] = Self.state(for: step, tool: tool)
            }
            switch await outcome {
            case .success:
                self?.states[tool] = .idle
                await finished()
            case .failure(let error):
                self?.states[tool] = error is CancellationError ? .idle : .failed(error.localizedDescription)
            }
            self?.tasks[tool] = nil
        }
    }

    func cancel(_ tool: ManagedTool) {
        tasks[tool]?.cancel()
    }

    func remove(_ tool: ManagedTool, finished: @escaping () async -> Void) {
        ToolStore.remove(tool)
        states[tool] = .idle
        Task { await finished() }
    }

    private static func state(for step: ToolInstallation.Step, tool: ManagedTool) -> ToolInstallState {
        switch step {
        case .lookingUp: .working(step: String(localized: "Looking up the latest version…"), fraction: nil)
        case .downloading(let fraction): .working(step: String(localized: "Downloading \(tool.displayName)…"), fraction: fraction)
        case .checking: .working(step: String(localized: "Checking the download…"), fraction: nil)
        case .unpacking: .working(step: String(localized: "Unpacking…"), fraction: nil)
        case .testing: .working(step: String(localized: "Testing…"), fraction: nil)
        }
    }
}
