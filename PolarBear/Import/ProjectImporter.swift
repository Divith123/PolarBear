//
//  ProjectImporter.swift
//  PolarBear
//

import Foundation

/// Brings a project archive (a Prism export, an Overleaf download, any `.zip` / `.tar.gz`) in as a
/// normal folder project. The archive is unpacked into a temporary folder first, checked, and
/// only moved next to the user's other projects once they confirm.
nonisolated enum ProjectImporter {
    private static let ignoredNames: Set<String> = ["__MACOSX", ".DS_Store"]

    /// Unpacks `archive` and describes what is inside.
    @concurrent
    static func prepare(archive: URL, toolchain: TeXToolchain) async throws -> ImportPreview {
        let fileManager = FileManager.default
        let staging = fileManager.temporaryDirectory.appending(path: "PolarBearImport-\(UUID().uuidString)", directoryHint: .isDirectory)
        try fileManager.createDirectory(at: staging, withIntermediateDirectories: true)

        do {
            try await ArchiveTool.unpack(archive, into: staging)
            let content = contentRoot(of: staging)
            var warnings = removeUnsafeItems(in: content)

            var texFiles: [(path: String, text: String)] = []
            var fileCount = 0
            if let enumerator = fileManager.enumerator(at: content, includingPropertiesForKeys: [.isRegularFileKey]) {
                while let url = enumerator.nextObject() as? URL {
                    guard (try? url.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true,
                          let path = ProjectPaths.relativePath(of: url, in: content),
                          !ignoredNames.contains(url.lastPathComponent) else { continue }
                    fileCount += 1
                    if path.hasSuffix(".tex"), let data = try? Data(contentsOf: url) {
                        texFiles.append((path, FileIO.decode(data).text))
                    }
                }
            }
            guard !texFiles.isEmpty else { throw ImportError.noLaTeX }

            let sources = texFiles.map { RootResolver.Source(path: $0.path, text: $0.text) }
            let rootFile = RootResolver.resolve(sources: sources, explicit: nil, active: nil)
            let allPackages = Array(Set(sources.flatMap { PackageScanner.packages(in: $0.text) })).sorted()

            var missing: [String]?
            if let kpsewhich = toolchain.kpsewhich {
                missing = await PackageScanner.missing(allPackages, using: kpsewhich, projectFiles: Set(texFiles.map(\.path)))
            }
            if rootFile == nil { warnings.append(String(localized: "No main document (\\documentclass) was found.")) }

            return ImportPreview(
                content: content,
                staging: staging,
                suggestedName: suggestedName(for: archive),
                fileCount: fileCount,
                rootFile: rootFile,
                packages: allPackages,
                missingPackages: missing,
                warnings: warnings
            )
        } catch {
            try? fileManager.removeItem(at: staging)
            throw error
        }
    }

    /// Moves the unpacked project to `parent/name` (numbered if taken). Returns the new folder.
    @concurrent
    static func finish(_ preview: ImportPreview, name: String, in parent: URL) async throws -> URL {
        let fileManager = FileManager.default
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines).replacing("/", with: "-").replacing(":", with: "-")
        let base = trimmed.isEmpty ? preview.suggestedName : trimmed

        var folder = parent.appending(path: base, directoryHint: .isDirectory)
        var counter = 2
        while fileManager.fileExists(atPath: folder.path(percentEncoded: false)) {
            folder = parent.appending(path: "\(base) \(counter)", directoryHint: .isDirectory)
            counter += 1
        }
        try fileManager.moveItem(at: preview.content, to: folder)
        try? fileManager.removeItem(at: preview.staging)
        return folder
    }

    @concurrent
    static func discard(_ preview: ImportPreview) async {
        try? FileManager.default.removeItem(at: preview.staging)
    }

    // MARK: Helpers

    /// Archives usually wrap everything in one folder; look inside it.
    private static func contentRoot(of staging: URL) -> URL {
        let fileManager = FileManager.default
        let entries = ((try? fileManager.contentsOfDirectory(atPath: staging.path(percentEncoded: false))) ?? [])
            .filter { !ignoredNames.contains($0) }
        guard entries.count == 1 else { return staging }
        let only = staging.appending(path: entries[0], directoryHint: .isDirectory)
        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: only.path(percentEncoded: false), isDirectory: &isDirectory), isDirectory.boolValue {
            return only
        }
        return staging
    }

    /// Symbolic links could point out of the project; they are removed.
    private static func removeUnsafeItems(in content: URL) -> [String] {
        let fileManager = FileManager.default
        var removed = 0
        if let enumerator = fileManager.enumerator(at: content, includingPropertiesForKeys: [.isSymbolicLinkKey]) {
            while let url = enumerator.nextObject() as? URL {
                if (try? url.resourceValues(forKeys: [.isSymbolicLinkKey]))?.isSymbolicLink == true {
                    try? fileManager.removeItem(at: url)
                    removed += 1
                }
            }
        }
        return removed > 0 ? [String(localized: "\(removed) symbolic links were left out for safety.")] : []
    }

    private static func suggestedName(for archive: URL) -> String {
        var name = archive.lastPathComponent
        for suffix in [".tar.gz", ".tgz", ".tar", ".zip"] where name.lowercased().hasSuffix(suffix) {
            name = String(name.dropLast(suffix.count))
        }
        return name.isEmpty ? String(localized: "Imported Project") : name
    }
}
