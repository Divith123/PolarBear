//
//  AgentAdapter.swift
//  PolarBear
//

import Foundation

/// One agent CLI behind a common contract: how to start it with a prompt, and how to read its
/// output. Everything agent-specific lives in the adapter.
nonisolated protocol AgentAdapter: Sendable {
    var kind: AgentKind { get }

    /// The command for a prompt. `resume` is the session to continue, if the CLI supports it;
    /// `options` are the model and effort the user picked.
    func command(prompt: String, resume: String?, options: AgentOptions) -> AgentCommand

    /// Turns one line of the CLI's output into events. `context` carries what earlier lines said.
    func events(from line: String, context: inout AgentParseContext) -> [AgentEvent]
}

extension AgentAdapter {
    /// Plain-text CLIs: each non-empty line is part of the answer, without terminal colours.
    nonisolated func plainTextEvents(from line: String) -> [AgentEvent] {
        let cleaned = line.replacing(/\u{1B}\[[0-9;?]*[A-Za-z]/, with: "")
        return cleaned.trimmingCharacters(in: .whitespaces).isEmpty ? [] : [.text(cleaned)]
    }
}
