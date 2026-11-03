//
//  FileTreeRowView.swift
//  PolarBear
//

import SwiftUI

/// Chooses the row view for one line of the file tree.
struct FileTreeRowView: View {
    let row: FileTreeRow
    let file: ProjectFile?
    let activeID: ProjectFile.ID?
    let actions: FileRowActions

    var body: some View {
        switch row.kind {
        case .folder(let isExpanded):
            FolderRow(path: row.path, depth: row.depth, isExpanded: isExpanded, actions: actions)
        case .file:
            if let file {
                FileRow(file: file, depth: row.depth, detail: row.detail, isActive: file.id == activeID, actions: actions)
            }
        case .asset:
            AssetRow(path: row.path, depth: row.depth, detail: row.detail, actions: actions)
        }
    }
}
