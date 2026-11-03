//
//  FilesList.swift
//  PolarBear
//

import SwiftUI

/// The project's files and folders as a tree, optionally narrowed by a filter field. Files
/// dropped from Finder are copied into the project.
struct FilesList: View {
    @Environment(WorkspaceModel.self) private var workspace
    @Binding var query: String
    let isSearching: Bool

    var body: some View {
        let project = workspace.project
        let rows = FileTree.rows(
            files: project.files,
            assets: project.assets,
            folders: project.folders,
            expanded: workspace.expandedFolders,
            query: query
        )
        let filesByID = Dictionary(project.files.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let actions = fileActions

        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
            if isSearching {
                FilterField(text: $query)
                    .padding(.top, AppTheme.Spacing.m)
            }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                    ForEach(rows) { row in
                        FileTreeRowView(
                            row: row,
                            file: fileID(of: row).flatMap { filesByID[$0] },
                            activeID: workspace.activeID,
                            actions: actions
                        )
                    }
                }
                .padding(.top, AppTheme.Spacing.xl)
            }
            .scrollIndicators(.hidden)
            .overlay {
                if rows.isEmpty {
                    FilesEmptyState(
                        projectHasFiles: !project.files.isEmpty || !project.assets.isEmpty,
                        query: query,
                        createFile: { workspace.promptNewFile() }
                    )
                }
            }
            .dropDestination(for: URL.self) { urls, _ in
                workspace.copyIn(urls)
                return !urls.isEmpty
            }

            if project.isTruncated {
                Label("This folder is very large. Only part of it is shown.", systemImage: "exclamationmark.triangle")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.warning)
                    .padding(.vertical, AppTheme.Spacing.s)
            }
        }
    }

    private func fileID(of row: FileTreeRow) -> ProjectFile.ID? {
        if case .file(let id) = row.kind { id } else { nil }
    }

    private var fileActions: FileRowActions {
        FileRowActions(
            open: workspace.open,
            rename: workspace.promptRename,
            duplicate: workspace.duplicate,
            reveal: { workspace.reveal(inFinder: $0) },
            delete: workspace.requestDelete,
            toggleFolder: workspace.toggleFolder,
            newFile: { workspace.promptNewFile(in: $0) },
            newFolder: { workspace.promptNewFolder(in: $0) },
            addFiles: { workspace.addFilesFromPanel(to: $0) },
            openExternally: { path in
                if let asset = workspace.project.assets.first(where: { $0.path == path }) {
                    workspace.openExternally(asset)
                }
            }
        )
    }
}
