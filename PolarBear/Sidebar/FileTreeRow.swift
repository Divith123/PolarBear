//
//  FileTreeRow.swift
//  PolarBear
//

import Foundation

/// One visible line of the sidebar's file tree.
struct FileTreeRow: Identifiable, Equatable {
    enum Kind: Equatable {
        case folder(isExpanded: Bool)
        case file(ProjectFile.ID)
        case asset
    }

    let path: String
    let kind: Kind
    let depth: Int
    /// Shown in place of the file name when a filter flattens the tree.
    var detail: String?

    var id: String { path }
    var name: String { ProjectPath.name(of: path) }
}
