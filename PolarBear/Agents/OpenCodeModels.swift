//
//  OpenCodeModels.swift
//  PolarBear
//

import Foundation

/// The models OpenCode can use on this Mac and the effort levels each one offers. The model
/// list comes from `opencode models`; the levels from OpenCode's own model data
/// (`~/.cache/opencode/models.json`), when that file is there.
nonisolated enum OpenCodeModels {
    struct Result: Sendable {
        var models: [String] = []
        /// `provider/model` → effort levels.
        var efforts: [String: [String]] = [:]
    }

    @concurrent
    static func load(executable: URL) async -> Result {
        var result = Result()
        let output = try? await ProcessRunner.run(
            executable: executable,
            arguments: ["models"],
            directory: FileManager.default.temporaryDirectory,
            environment: ProcessEnvironment.make(extraPaths: [executable.deletingLastPathComponent()] + ToolLocator.agentDirectories())
        )
        result.models = (output?.output ?? "")
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.contains("/") && AgentOptions.sanitised($0) != nil }
        guard !result.models.isEmpty else { return result }

        let cache = FileManager.default.homeDirectoryForCurrentUser.appending(path: ".cache/opencode/models.json")
        guard let data = try? Data(contentsOf: cache),
              let providers = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return result }

        for identifier in result.models {
            guard let slash = identifier.firstIndex(of: "/") else { continue }
            let provider = String(identifier[..<slash])
            let model = String(identifier[identifier.index(after: slash)...])
            let entry = ((providers[provider] as? [String: Any])?["models"] as? [String: Any])?[model] as? [String: Any]
            let options = entry?["reasoning_options"] as? [[String: Any]] ?? []
            let levels = options.first { $0["type"] as? String == "effort" }?["values"] as? [String] ?? []
            if !levels.isEmpty { result.efforts[identifier] = levels }
        }
        return result
    }
}
