//
//  AgentKind.swift
//  PolarBear
//

import Foundation

/// The command-line agents PolarBear can drive. They are programs the user installed and
/// signed in to themselves; PolarBear never sees their credentials.
nonisolated enum AgentKind: String, CaseIterable, Identifiable, Codable, Sendable {
    case claudeCode
    case codex
    case openCode
    case gemini

    var id: String { rawValue }

    /// Product names, not localised.
    var displayName: String {
        switch self {
        case .claudeCode: "Claude Code"
        case .codex: "Codex CLI"
        case .openCode: "OpenCode"
        case .gemini: "Gemini CLI"
        }
    }

    /// The program that is looked for on this Mac.
    var executableName: String {
        switch self {
        case .claudeCode: "claude"
        case .codex: "codex"
        case .openCode: "opencode"
        case .gemini: "gemini"
        }
    }

    /// Where the project's text goes when this agent runs.
    var privacyNote: LocalizedStringResource {
        switch self {
        case .claudeCode: "Sends your project's text to Anthropic, using your own Claude login."
        case .codex: "Sends your project's text to OpenAI, using your own ChatGPT or API login."
        case .openCode: "Sends your project's text to whichever AI provider you configured in OpenCode."
        case .gemini: "Sends your project's text to Google, using your own Gemini login."
        }
    }

    var installHint: String {
        switch self {
        case .claudeCode: "npm install -g @anthropic-ai/claude-code"
        case .codex: "npm install -g @openai/codex"
        case .openCode: "brew install sst/tap/opencode"
        case .gemini: "npm install -g @google/gemini-cli"
        }
    }

    /// Models offered in the picker besides "Default" and a custom id. OpenCode's come from the
    /// program itself (`opencode models`), the others change too quickly to list.
    var suggestedModels: [String] {
        switch self {
        case .claudeCode: ["sonnet", "opus", "haiku"]
        case .gemini: ["gemini-2.5-pro", "gemini-2.5-flash"]
        case .codex, .openCode: []
        }
    }

    /// The reasoning-effort levels the CLI accepts. OpenCode's depend on the model; Gemini has none.
    var effortLevels: [String] {
        switch self {
        case .claudeCode: ["low", "medium", "high", "xhigh", "max"]
        case .codex: ["minimal", "low", "medium", "high", "xhigh"]
        case .openCode, .gemini: []
        }
    }

    var adapter: any AgentAdapter {
        switch self {
        case .claudeCode: ClaudeCodeAdapter()
        case .codex: CodexAdapter()
        case .openCode: OpenCodeAdapter()
        case .gemini: GeminiAdapter()
        }
    }
}
