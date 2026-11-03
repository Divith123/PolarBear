//
//  AgentEvent.swift
//  PolarBear
//

import Foundation

/// What an agent's output means.
nonisolated enum AgentEvent: Sendable {
    /// A line of the answer.
    case text(String)
    /// What the agent is doing right now ("Reading main.tex").
    case activity(String)
    /// An identifier that lets the conversation continue later.
    case session(String)
    case failure(String)
    /// The agent finished; the associated text is its final message, if it gave one.
    case finished(String?)
}
