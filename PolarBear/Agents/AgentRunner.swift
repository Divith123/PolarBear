//
//  AgentRunner.swift
//  PolarBear
//

import Foundation
import os

/// Starts an agent CLI and turns its output into events. The prompt is one argument of an
/// argument array, so nothing in a document or a prompt can be run as a shell command.
nonisolated enum AgentRunner {
    struct Outcome: Sendable {
        var status: Int32
        var wasCancelled: Bool
        var summary: String?
        var failure: String?
        var sessionID: String?
    }

    @concurrent
    static func run(
        adapter: any AgentAdapter,
        executable: URL,
        command: AgentCommand,
        directory: URL,
        onEvent: @escaping @Sendable (AgentEvent) -> Void
    ) async throws -> Outcome {
        let state = OSAllocatedUnfairLock(
            initialState: (splitter: LineSplitter(), context: AgentParseContext(), summary: String?.none, failure: String?.none, session: String?.none)
        )

        let handle: @Sendable (String) -> Void = { line in
            let events = state.withLock { values in adapter.events(from: line, context: &values.context) }
            for event in events {
                state.withLock { values in
                    switch event {
                    case .finished(let text): values.summary = text
                    case .failure(let text): values.failure = text
                    case .session(let id): values.session = id
                    default: break
                    }
                }
                onEvent(event)
            }
        }

        var searchPaths = [executable.deletingLastPathComponent()]
        searchPaths += ToolLocator.agentDirectories()
        let environment = ProcessEnvironment.make(extraPaths: searchPaths, extra: command.environment)

        let result = try await ProcessRunner.run(
            executable: executable,
            arguments: command.arguments,
            directory: directory,
            environment: environment
        ) { chunk in
            let lines = state.withLock { $0.splitter.feed(chunk) }
            for line in lines { handle(line) }
        }
        if let last = state.withLock({ $0.splitter.flush() }) { handle(last) }

        let snapshot = state.withLock { $0 }
        return Outcome(
            status: result.status,
            wasCancelled: result.wasCancelled,
            summary: snapshot.summary,
            failure: snapshot.failure,
            sessionID: snapshot.session
        )
    }
}
