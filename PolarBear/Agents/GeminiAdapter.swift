//
//  GeminiAdapter.swift
//  PolarBear
//

import Foundation

/// Google's Gemini CLI in non-interactive mode (`gemini -p`), approving edits but not shell commands.
nonisolated struct GeminiAdapter: AgentAdapter {
    var kind: AgentKind { .gemini }

    func command(prompt: String, resume: String?, options: AgentOptions) -> AgentCommand {
        var arguments = ["--approval-mode", "auto_edit"]
        if let model = options.model { arguments += ["--model", model] }
        arguments += ["-p", prompt]
        return AgentCommand(arguments: arguments)
    }

    func events(from line: String, context: inout AgentParseContext) -> [AgentEvent] {
        plainTextEvents(from: line)
    }
}
