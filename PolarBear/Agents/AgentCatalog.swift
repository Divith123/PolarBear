//
//  AgentCatalog.swift
//  PolarBear
//

import Foundation
import Observation

/// Which agents are installed on this Mac, which one the user prefers, and the model and effort
/// chosen for each.
@Observable
final class AgentCatalog {
    private static let preferredKey = "preferredAgent"
    private static let optionsKey = "agentOptions"

    private(set) var installed: [AgentKind: URL] = [:]
    private(set) var hasSearched = false
    private(set) var options: [AgentKind: AgentOptions] = [:]
    /// OpenCode's models and their effort levels, once read.
    private(set) var openCodeModels = OpenCodeModels.Result()

    /// The agent chosen in Settings for projects that have not chosen their own.
    var preferred: AgentKind? {
        didSet { UserDefaults.standard.set(preferred?.rawValue, forKey: Self.preferredKey) }
    }

    init() {
        preferred = UserDefaults.standard.string(forKey: Self.preferredKey).flatMap(AgentKind.init(rawValue:))
        if let data = UserDefaults.standard.data(forKey: Self.optionsKey),
           let stored = try? JSONDecoder().decode([String: AgentOptions].self, from: data) {
            options = Dictionary(uniqueKeysWithValues: stored.compactMap { key, value in
                AgentKind(rawValue: key).map { ($0, value) }
            })
        }
    }

    func refresh() async {
        installed = await Self.discover()
        hasSearched = true
        if let opencode = installed[.openCode] {
            openCodeModels = await OpenCodeModels.load(executable: opencode)
        }
    }

    /// The agent a project would use now: its own choice, else the preferred one, else the first installed.
    func effective(for project: Project) -> AgentKind? {
        let candidates = [project.settings.selectedAgent.flatMap(AgentKind.init(rawValue:)), preferred]
        for candidate in candidates {
            if let candidate, installed[candidate] != nil { return candidate }
        }
        return AgentKind.allCases.first { installed[$0] != nil }
    }

    // MARK: Model and effort

    func options(for kind: AgentKind) -> AgentOptions {
        options[kind] ?? AgentOptions()
    }

    /// The models to list for `kind`, besides "Default".
    func models(for kind: AgentKind) -> [String] {
        kind == .openCode ? openCodeModels.models : kind.suggestedModels
    }

    /// The effort levels `kind` offers for the model chosen now (none if it has no such setting).
    func efforts(for kind: AgentKind) -> [String] {
        guard kind == .openCode else { return kind.effortLevels }
        guard let model = options(for: kind).model else { return [] }
        return openCodeModels.efforts[model] ?? []
    }

    func setModel(_ model: String?, for kind: AgentKind) {
        var current = options(for: kind)
        current.model = AgentOptions.sanitised(model)
        // A level that the new model does not offer is dropped rather than sent.
        if let effort = current.effort, kind == .openCode, !(openCodeModels.efforts[current.model ?? ""] ?? []).contains(effort) {
            current.effort = nil
        }
        store(current, for: kind)
    }

    func setEffort(_ effort: String?, for kind: AgentKind) {
        var current = options(for: kind)
        current.effort = AgentOptions.sanitised(effort)
        store(current, for: kind)
    }

    /// "OpenCode · big-pickle · high": what the composer's chip shows.
    func summary(for kind: AgentKind) -> String {
        let chosen = options(for: kind)
        let model = chosen.model.map { String($0.split(separator: "/").last ?? Substring($0)) }
        return [kind.displayName, model, chosen.effort].compactMap { $0 }.joined(separator: " · ")
    }

    private func store(_ value: AgentOptions, for kind: AgentKind) {
        options[kind] = value
        let encodable = Dictionary(uniqueKeysWithValues: options.map { ($0.key.rawValue, $0.value) })
        if let data = try? JSONEncoder().encode(encodable) {
            UserDefaults.standard.set(data, forKey: Self.optionsKey)
        }
    }

    @concurrent
    private static func discover() async -> [AgentKind: URL] {
        let directories = ToolLocator.agentDirectories()
        var found: [AgentKind: URL] = [:]
        for kind in AgentKind.allCases {
            if let url = ToolLocator.find(kind.executableName, in: directories) { found[kind] = url }
        }
        return found
    }
}
