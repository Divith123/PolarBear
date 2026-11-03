//
//  ProjectScanner.swift
//  PolarBear
//

import Foundation

/// Walks a project folder and reports its files. Files whose fingerprint matches one in
/// `known` are not read again, so re-scanning after a file-system event is cheap.
nonisolated enum ProjectScanner {
    static let maximumTextSize = 8_000_000
    /// A folder far bigger than a LaTeX project (a home folder opened by mistake) must not freeze the app.
    static let maximumEntries = 20_000
    static let maximumTextBytes = 200_000_000
    private static let skippedFolders: Set<String> = ["node_modules", "__pycache__"]

    struct ScannedFile: Sendable {
        enum Content: Sendable {
            case unchanged
            case loaded(FileIO.DecodedText)
        }

        var path: String
        var stamp: FileStamp
        var content: Content
    }

    struct Scan: Sendable {
        var files: [ScannedFile] = []
        var assets: [String] = []
        var folders: [String] = []
        /// The folder had more than the app reads; the rest was left out.
        var isTruncated = false
    }

    @concurrent
    static func scan(root: URL, known: [String: FileStamp]) async -> Scan {
        var result = Scan()
        let keys: [URLResourceKey] = [.isDirectoryKey, .contentModificationDateKey, .fileSizeKey]
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return result }

        var entries = 0
        var textBytes = 0
        while let url = enumerator.nextObject() as? URL {
            entries += 1
            if entries > maximumEntries {
                result.isTruncated = true
                break
            }
            guard let path = ProjectPaths.relativePath(of: url, in: root) else { continue }
            let name = url.lastPathComponent
            let values = try? url.resourceValues(forKeys: Set(keys))

            if values?.isDirectory == true {
                if skippedFolders.contains(name) {
                    enumerator.skipDescendants()
                } else {
                    result.folders.append(path)
                }
                continue
            }
            if FileKind.isGenerated(name: name) { continue }

            let stamp = FileStamp(modified: values?.contentModificationDate ?? .distantPast, size: values?.fileSize ?? 0)
            guard FileKind(path: path).isText, stamp.size <= maximumTextSize, textBytes + stamp.size <= maximumTextBytes else {
                if FileKind(path: path).isText { result.isTruncated = true }
                result.assets.append(path)
                continue
            }
            textBytes += stamp.size
            if known[path] == stamp {
                result.files.append(ScannedFile(path: path, stamp: stamp, content: .unchanged))
            } else if let data = try? Data(contentsOf: url) {
                result.files.append(ScannedFile(path: path, stamp: stamp, content: .loaded(FileIO.decode(data))))
            }
        }
        result.files.sort { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
        result.assets.sort { $0.localizedStandardCompare($1) == .orderedAscending }
        result.folders.sort { $0.localizedStandardCompare($1) == .orderedAscending }
        return result
    }
}
