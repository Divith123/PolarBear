//
//  HistoryStore.swift
//  PolarBear
//

import CryptoKit
import Foundation
import os

/// Reads and writes a project's history under `.PolarBear/history`: an `index.json` with the
/// list of versions and a `blobs` folder holding each distinct file text once, named by its
/// SHA-256. No Git needed, and unchanged files cost nothing.
nonisolated enum HistoryStore {
    private static let hexDigits = Array("0123456789abcdef")

    static func hash(of text: String) -> String {
        var result = ""
        for byte in SHA256.hash(data: Data(text.utf8)) {
            result.append(hexDigits[Int(byte >> 4)])
            result.append(hexDigits[Int(byte & 0x0F)])
        }
        return result
    }

    private static func blobURL(_ hash: String, root: URL) -> URL {
        ProjectPaths.historyDirectory(in: root).appending(path: "blobs/\(hash)")
    }

    private static func indexURL(root: URL) -> URL {
        ProjectPaths.historyDirectory(in: root).appending(path: "index.json")
    }

    /// Newest first.
    @concurrent
    static func load(root: URL) async -> [VersionRecord] {
        guard let data = try? Data(contentsOf: indexURL(root: root)) else { return [] }
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([VersionRecord].self, from: data)
        } catch {
            Log.history.error("Unreadable history index: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    @concurrent
    static func save(_ versions: [VersionRecord], root: URL) async {
        ProjectPaths.prepareMetadata(in: root)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        do {
            try FileManager.default.createDirectory(at: ProjectPaths.historyDirectory(in: root), withIntermediateDirectories: true)
            try encoder.encode(versions).write(to: indexURL(root: root), options: .atomic)
        } catch {
            Log.history.error("Could not save the history index: \(error.localizedDescription, privacy: .public)")
        }
    }

    @concurrent
    static func text(forHash hash: String, root: URL) async -> String? {
        guard let data = try? Data(contentsOf: blobURL(hash, root: root)) else { return nil }
        return String(decoding: data, as: UTF8.self)
    }

    /// The text of every file of a version.
    @concurrent
    static func texts(of manifest: [String: String], root: URL) async -> [String: String] {
        var result: [String: String] = [:]
        for (path, hash) in manifest {
            if let text = await text(forHash: hash, root: root) { result[path] = text }
        }
        return result
    }

    /// Stores the sources as a new version. Returns `nil` when nothing changed since `previous`.
    @concurrent
    static func record(
        sources: [HistorySource],
        previous: VersionRecord?,
        kind: VersionRecord.Kind,
        title: String?,
        root: URL
    ) async -> VersionRecord? {
        let fileManager = FileManager.default
        var manifest: [String: String] = [:]
        var texts: [String: String] = [:]
        for source in sources {
            let hash = hash(of: source.text)
            manifest[source.path] = hash
            texts[source.path] = source.text
            let blob = blobURL(hash, root: root)
            guard !fileManager.fileExists(atPath: blob.path(percentEncoded: false)) else { continue }
            do {
                try fileManager.createDirectory(at: blob.deletingLastPathComponent(), withIntermediateDirectories: true)
                try Data(source.text.utf8).write(to: blob, options: .atomic)
            } catch {
                Log.history.error("Could not store a file version: \(error.localizedDescription, privacy: .public)")
            }
        }
        if let previous, previous.manifest == manifest { return nil }

        let before = previous?.manifest ?? [:]
        let changed = Set(manifest.keys).union(before.keys)
            .filter { manifest[$0] != before[$0] }
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }

        var added = 0
        var removed = 0
        for path in changed {
            let oldText: String
            if let oldHash = before[path] {
                oldText = await text(forHash: oldHash, root: root) ?? ""
            } else {
                oldText = ""
            }
            let counts = TextDiff.counts(old: oldText, new: texts[path] ?? "")
            added += counts.added
            removed += counts.removed
        }

        return VersionRecord(
            number: (previous?.number ?? 0) + 1,
            date: .now,
            title: title ?? automaticTitle(changed: changed, manifest: manifest, before: before, isFirst: previous == nil),
            kind: previous == nil ? .initial : kind,
            added: added,
            removed: removed,
            changedFiles: changed,
            manifest: manifest
        )
    }

    private static func automaticTitle(changed: [String], manifest: [String: String], before: [String: String], isFirst: Bool) -> String {
        if isFirst { return "Initial version" }
        let names = changed.map { $0.split(separator: "/").last.map(String.init) ?? $0 }
        let verb: String
        if changed.allSatisfy({ before[$0] == nil }) {
            verb = "Added"
        } else if changed.allSatisfy({ manifest[$0] == nil }) {
            verb = "Deleted"
        } else {
            verb = "Edited"
        }
        switch names.count {
        case 0: return "No changes"
        case 1...2: return "\(verb) \(names.joined(separator: ", "))"
        default: return "\(verb) \(names.count) files"
        }
    }
}
