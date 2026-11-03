//
//  VersionRecord.swift
//  PolarBear
//

import Foundation

/// One entry of a project's history: the full set of files at a moment, stored by content hash.
nonisolated struct VersionRecord: Codable, Identifiable, Hashable, Sendable {
    enum Kind: String, Codable, Sendable {
        case initial
        case automatic
        case manual
        case agent
        case restore
    }

    var id = UUID()
    var number: Int
    var date: Date
    var title: String
    var kind: Kind
    /// Lines added and removed compared with the previous version.
    var added: Int
    var removed: Int
    var changedFiles: [String]
    /// Project-relative path → hash of the file's text (see `HistoryStore`).
    var manifest: [String: String]
}
