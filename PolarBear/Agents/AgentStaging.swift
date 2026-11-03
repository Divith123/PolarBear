//
//  AgentStaging.swift
//  PolarBear
//

import Foundation

/// Makes the temporary working copy for an agent run and reads back what the agent changed.
/// Only the project's source text is copied — never `.env` files, keys or other secrets, build
/// output or version-control data.
nonisolated enum AgentStaging {
    /// Names that are never copied, whatever their extension.
    private static let deniedNames = [".env", "id_rsa", "id_ed25519", ".npmrc", ".netrc", "credentials", "secrets"]
    private static let deniedExtensions: Set<String> = ["pem", "key", "p12", "keychain", "env"]

    static func isAllowed(_ path: String) -> Bool {
        let name = ProjectPath.name(of: path).lowercased()
        if deniedNames.contains(where: { name.hasPrefix($0) }) { return false }
        return !deniedExtensions.contains(ProjectPath.fileExtension(of: path).lowercased())
    }

    @concurrent
    static func create(from sources: [HistorySource], extras: [TemplateFile]) async throws -> StagedProject {
        let fileManager = FileManager.default
        let container = fileManager.temporaryDirectory.appending(path: "PolarBearAgent-\(UUID().uuidString)", directoryHint: .isDirectory)
        let root = container.appending(path: "project", directoryHint: .isDirectory)
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)

        var baseline: [String: String] = [:]
        for source in sources where isAllowed(source.path) {
            let url = root.appending(path: source.path)
            try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data(source.text.utf8).write(to: url)
            baseline[source.path] = source.text
        }
        for file in extras {
            let url = root.appending(path: file.path)
            try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data(file.text.utf8).write(to: url)
        }
        return StagedProject(container: container, root: root, baseline: baseline, extras: Set(extras.map(\.path)))
    }

    /// The text of every allowed file in the working copy now.
    @concurrent
    static func collect(_ staged: StagedProject) async -> [String: String] {
        let scan = await ProjectScanner.scan(root: staged.root, known: [:])
        var result: [String: String] = [:]
        for file in scan.files {
            guard case .loaded(let decoded) = file.content, !staged.extras.contains(file.path), isAllowed(file.path) else { continue }
            result[file.path] = decoded.text
        }
        return result
    }

    static func remove(_ staged: StagedProject) {
        try? FileManager.default.removeItem(at: staged.container)
    }
}
