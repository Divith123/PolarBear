//
//  ProjectCreator.swift
//  PolarBear
//

import Foundation

/// Creates a new project folder from a template.
nonisolated enum ProjectCreator {
    enum CreationError: LocalizedError {
        case emptyName

        var errorDescription: String? {
            String(localized: "Give the project a name.")
        }
    }

    /// Makes `parent/name` (numbered if the name is taken) and writes the template's files.
    @concurrent
    static func create(name: String, from files: [TemplateFile], in parent: URL) async throws -> URL {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines).replacing("/", with: "-").replacing(":", with: "-")
        guard !trimmed.isEmpty else { throw CreationError.emptyName }

        let fileManager = FileManager.default
        var folder = parent.appending(path: trimmed, directoryHint: .isDirectory)
        var counter = 2
        while fileManager.fileExists(atPath: folder.path(percentEncoded: false)) {
            folder = parent.appending(path: "\(trimmed) \(counter)", directoryHint: .isDirectory)
            counter += 1
        }

        try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        for file in files {
            let url = folder.appending(path: file.path)
            try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data(file.text.utf8).write(to: url, options: .atomic)
        }
        return folder
    }
}
