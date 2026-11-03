//
//  FileChange.swift
//  PolarBear
//

import Foundation

/// How one file differs between two versions (or between an agent's proposal and the project).
nonisolated struct FileChange: Identifiable, Hashable, Sendable {
    enum Status: Sendable {
        case added
        case modified
        case deleted
    }

    var path: String
    var status: Status
    var old: String
    var new: String
    var hunks: [TextDiff.Hunk]

    var id: String { path }
    var added: Int { hunks.reduce(0) { $0 + $1.added } }
    var removed: Int { hunks.reduce(0) { $0 + $1.removed } }

    /// Compares two sets of file texts.
    static func changes(old: [String: String], new: [String: String]) -> [FileChange] {
        let paths = Set(old.keys).union(new.keys).sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        return paths.compactMap { path in
            let before = old[path]
            let after = new[path]
            guard before != after else { return nil }
            let status: Status = before == nil ? .added : (after == nil ? .deleted : .modified)
            let hunks = TextDiff.hunks(old: before ?? "", new: after ?? "")
            return FileChange(path: path, status: status, old: before ?? "", new: after ?? "", hunks: hunks)
        }
    }
}
