//
//  OpenCodeAdapter.swift
//  PolarBear
//

import Foundation

/// OpenCode's non-interactive mode (`opencode run`). A configuration file in the working
/// folder lets it edit files but forbids shell commands and web access.
nonisolated struct OpenCodeAdapter: AgentAdapter {
    var kind: AgentKind { .openCode }

    private static let configuration = """
    {
      "$schema": "https://opencode.ai/config.json",
      "permission": { "edit": "allow", "bash": "deny", "webfetch": "deny" }
    }
    """

    func command(prompt: String, resume: String?, options: AgentOptions) -> AgentCommand {
        var arguments = ["run", "--auto"]
        if let model = options.model {
            // `provider/model#variant`: for OpenCode the effort level is the model's variant.
            arguments += ["--model", options.effort.map { "\(model)#\($0)" } ?? model]
        }
        if let resume { arguments += ["--session", resume] }
        arguments.append(prompt)
        return AgentCommand(
            arguments: arguments,
            files: [TemplateFile(path: "opencode.json", text: Self.configuration)]
        )
    }

    /// OpenCode prints a `> agent · model` header before every step, then a marker line for each
    /// tool it uses (`→ Read main.tex`, `← Edit main.tex` followed by a diff), then its answer.
    /// The markers become short activity lines; tool output is left out of the answer.
    func events(from line: String, context: inout AgentParseContext) -> [AgentEvent] {
        let plain = line.replacing(/\u{1B}\[[0-9;?]*[A-Za-z]/, with: "")
        let trimmed = plain.trimmingCharacters(in: .whitespaces)

        if trimmed.hasPrefix("> "), trimmed.contains(" · ") {
            context.isInToolOutput = false
            return []
        }
        for marker in ["→ ", "← ", "✱ ", "⚙ "] where trimmed.hasPrefix(marker) {
            context.isInToolOutput = true
            return [.activity(Self.describe(String(trimmed.dropFirst(marker.count))))]
        }
        if context.isInToolOutput { return [] }
        return trimmed.isEmpty ? [] : [.text(plain)]
    }

    /// "Read main.tex" → "Reading main.tex".
    private static func describe(_ step: String) -> String {
        let parts = step.split(separator: " ", maxSplits: 1).map(String.init)
        guard let tool = parts.first else { return step }
        let target = parts.count > 1 ? String(parts[1].prefix(80)).trimmingCharacters(in: .whitespaces) : ""
        switch tool {
        case "Read": return "Reading \(target)"
        case "Edit": return "Editing \(target)"
        case "Write": return "Writing \(target)"
        case "Patch": return "Patching \(target)"
        case "Grep": return "Searching for \(target)"
        case "Glob", "List": return "Looking through the project"
        case "execute": return "Running a script"
        default: return step
        }
    }
}
