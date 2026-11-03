//
//  FileTree.swift
//  PolarBear
//

import Foundation

/// Turns the project's flat lists of files, assets and folders into the rows of the tree.
enum FileTree {
    static func rows(
        files: [ProjectFile],
        assets: [ProjectAsset],
        folders: [String],
        expanded: Set<String>,
        query: String
    ) -> [FileTreeRow] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            return filtered(files: files, assets: assets, query: trimmed)
        }

        var children: [String: [FileTreeRow]] = [:]
        func add(_ path: String, _ kind: FileTreeRow.Kind) {
            let parent = ProjectPath.parent(of: path)
            children[parent, default: []].append(FileTreeRow(path: path, kind: kind, depth: 0))
        }
        for folder in folders { add(folder, .folder(isExpanded: expanded.contains(folder))) }
        for file in files { add(file.path, .file(file.id)) }
        for asset in assets { add(asset.path, .asset) }

        var result: [FileTreeRow] = []
        func append(parent: String, depth: Int) {
            let ordered = (children[parent] ?? []).sorted { lhs, rhs in
                let leftIsFolder = lhs.isFolder
                let rightIsFolder = rhs.isFolder
                if leftIsFolder != rightIsFolder { return leftIsFolder }
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
            for row in ordered {
                result.append(FileTreeRow(path: row.path, kind: row.kind, depth: depth))
                if case .folder(isExpanded: true) = row.kind {
                    append(parent: row.path, depth: depth + 1)
                }
            }
        }
        append(parent: "", depth: 0)
        return result
    }

    /// A filter shows matching files in a flat list, with their folder underneath.
    private static func filtered(files: [ProjectFile], assets: [ProjectAsset], query: String) -> [FileTreeRow] {
        let fileRows = files.filter { $0.path.localizedStandardContains(query) }
            .map { FileTreeRow(path: $0.path, kind: .file($0.id), depth: 0, detail: detail(of: $0.path)) }
        let assetRows = assets.filter { $0.path.localizedStandardContains(query) }
            .map { FileTreeRow(path: $0.path, kind: .asset, depth: 0, detail: detail(of: $0.path)) }
        return fileRows + assetRows
    }

    private static func detail(of path: String) -> String? {
        let parent = ProjectPath.parent(of: path)
        return parent.isEmpty ? nil : parent
    }
}

private extension FileTreeRow {
    var isFolder: Bool {
        if case .folder = kind { true } else { false }
    }
}
