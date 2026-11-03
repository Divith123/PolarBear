//
//  CodexAdapter.swift
//  PolarBear
//

import Foundation

/// OpenAI's Codex CLI in non-interactive mode (`codex exec`). Its sandbox only lets it write
/// inside the working folder, which is a temporary copy of the project.
nonisolated struct CodexAdapter: AgentAdapter {
    var kind: AgentKind { .codex }

    func command(prompt: String, resume: String?, options: AgentOptions) -> AgentCommand {
        var arguments = ["exec", "--sandbox", "workspace-write", "--skip-git-repo-check", "--color", "never"]
        if let model = options.model { arguments += ["--model", model] }
        if let effort = options.effort { arguments += ["-c", "model_reasoning_effort=\"\(effort)\""] }
        arguments.append(prompt)
        return AgentCommand(arguments: arguments)
    }

    func events(from line: String, context: inout AgentParseContext) -> [AgentEvent] {
        plainTextEvents(from: line)
    }
}
