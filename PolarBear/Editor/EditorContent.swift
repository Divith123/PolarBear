//
//  EditorContent.swift
//  PolarBear
//

import SwiftUI

/// The code editor, or an empty state when no tab is open. A banner appears when the open
/// file changed on disk while it had unsaved edits.
struct EditorContent: View {
    @Environment(WorkspaceModel.self) private var workspace

    var body: some View {
        let openFiles = workspace.openFiles

        ZStack {
            CodeEditor(
                openFiles: openFiles,
                activeID: workspace.activeID,
                reveal: workspace.revealRequest,
                diagnostics: workspace.project.build.diagnostics,
                externalRevisions: openFiles.map(\.externalRevision),
                onTextChange: workspace.textDidChange(in:),
                onCommandClick: workspace.syncPDF(file:line:),
                onCaretMove: workspace.caretMoved(in:to:)
            )

            if openFiles.isEmpty {
                EditorEmptyState()
            }
        }
        .overlay(alignment: .top) {
            if let file = workspace.activeFile, file.conflict != nil {
                ConflictBanner(file: file, project: workspace.project)
            }
        }
    }
}
