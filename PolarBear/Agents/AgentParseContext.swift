//
//  AgentParseContext.swift
//  PolarBear
//

import Foundation

/// What an adapter remembers between the lines of one run.
nonisolated struct AgentParseContext: Sendable {
    /// The CLI is printing the output of a tool (a diff, a file listing) rather than its answer.
    var isInToolOutput = false
}
