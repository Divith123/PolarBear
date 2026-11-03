//
//  AgentCommand.swift
//  PolarBear
//

import Foundation

/// How to start one agent run: the arguments (never joined into a shell string), extra
/// environment variables, and configuration files to put in the working folder first.
nonisolated struct AgentCommand: Sendable {
    var arguments: [String]
    var environment: [String: String] = [:]
    var files: [TemplateFile] = []
}
