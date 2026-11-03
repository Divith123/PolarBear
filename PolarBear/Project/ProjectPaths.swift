//
//  ProjectPaths.swift
//  PolarBear
//

import Foundation
import os

/// Where the app keeps its own files inside a project folder. Everything lives in one hidden
/// folder, which also holds a `.gitignore` so version control leaves it alone.
nonisolated enum ProjectPaths {
    static let metadataFolderName = ".PolarBear"

    static func metadata(in root: URL) -> URL {
        root.appending(path: metadataFolderName, directoryHint: .isDirectory)
    }

    static func settingsFile(in root: URL) -> URL {
        metadata(in: root).appending(path: "project.json")
    }

    /// Where the engine writes everything it produces.
    static func buildDirectory(in root: URL) -> URL {
        metadata(in: root).appending(path: "build", directoryHint: .isDirectory)
    }

    /// The last PDF that compiled without errors.
    static func publishedDirectory(in root: URL) -> URL {
        metadata(in: root).appending(path: "published", directoryHint: .isDirectory)
    }

    /// Downloaded copies of the web images a Markdown document uses.
    static func imageCacheDirectory(in root: URL) -> URL {
        metadata(in: root).appending(path: "cache/images", directoryHint: .isDirectory)
    }

    static func historyDirectory(in root: URL) -> URL {
        metadata(in: root).appending(path: "history", directoryHint: .isDirectory)
    }

    static func chatsDirectory(in root: URL) -> URL {
        metadata(in: root).appending(path: "chats", directoryHint: .isDirectory)
    }

    /// Creates the metadata folder (and its `.gitignore`) when it is missing.
    static func prepareMetadata(in root: URL) {
        let folder = metadata(in: root)
        let ignore = folder.appending(path: ".gitignore")
        guard !FileManager.default.fileExists(atPath: ignore.path(percentEncoded: false)) else { return }
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try Data("*\n".utf8).write(to: ignore)
        } catch {
            Log.project.error("Could not prepare the metadata folder: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// The path of `url` relative to `root`, or `nil` when it lies outside the project.
    static func relativePath(of url: URL, in root: URL) -> String? {
        let rootPath = root.standardizedFileURL.path(percentEncoded: false)
        let path = url.standardizedFileURL.path(percentEncoded: false)
        let prefix = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"
        guard path.hasPrefix(prefix) else { return nil }
        var relative = String(path.dropFirst(prefix.count))
        while relative.hasSuffix("/") { relative.removeLast() } // folders come with a trailing slash
        return relative
    }
}
