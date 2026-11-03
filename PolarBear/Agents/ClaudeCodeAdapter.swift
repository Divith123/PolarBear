//
//  ClaudeCodeAdapter.swift
//  PolarBear
//

import Foundation

/// Claude Code in headless mode (`claude -p`), streaming one JSON event per line. Edits are
/// accepted automatically — they happen in a temporary copy of the project — but shell commands
/// are not allowed.
nonisolated struct ClaudeCodeAdapter: AgentAdapter {
    var kind: AgentKind { .claudeCode }

    func command(prompt: String, resume: String?, options: AgentOptions) -> AgentCommand {
        var arguments = [
            "-p", prompt,
            "--output-format", "stream-json", "--verbose",
            "--permission-mode", "acceptEdits",
            "--allowedTools", "Read,Edit,MultiEdit,Write,Glob,Grep",
        ]
        if let model = options.model { arguments += ["--model", model] }
        if let effort = options.effort { arguments += ["--effort", effort] }
        if let resume { arguments += ["--resume", resume] }
        return AgentCommand(arguments: arguments)
    }

    func events(from line: String, context: inout AgentParseContext) -> [AgentEvent] {
        guard let data = line.data(using: .utf8),
              let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let type = object["type"] as? String else {
            return plainTextEvents(from: line)
        }

        switch type {
        case "system":
            return (object["session_id"] as? String).map { [.session($0)] } ?? []
        case "assistant":
            let content = (object["message"] as? [String: Any])?["content"] as? [[String: Any]] ?? []
            return content.compactMap { item in
                switch item["type"] as? String {
                case "text":
                    (item["text"] as? String).map(AgentEvent.text)
                case "tool_use":
                    .activity(Self.describe(tool: item["name"] as? String ?? "", input: item["input"] as? [String: Any] ?? [:]))
                default:
                    nil
                }
            }
        case "result":
            var events: [AgentEvent] = []
            if let session = object["session_id"] as? String { events.append(.session(session)) }
            if object["is_error"] as? Bool == true {
                events.append(.failure(object["result"] as? String ?? "Claude Code reported an error."))
            } else {
                events.append(.finished(object["result"] as? String))
            }
            return events
        default:
            return []
        }
    }

    private static func describe(tool: String, input: [String: Any]) -> String {
        let path = (input["file_path"] as? String ?? input["path"] as? String).map { ($0 as NSString).lastPathComponent }
        switch tool {
        case "Read": return "Reading \(path ?? "a file")"
        case "Edit", "MultiEdit": return "Editing \(path ?? "a file")"
        case "Write": return "Writing \(path ?? "a file")"
        case "Glob", "Grep": return "Searching the project"
        default: return tool
        }
    }
}
