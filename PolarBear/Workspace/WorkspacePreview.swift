//
//  WorkspacePreview.swift
//  PolarBear
//

import SwiftUI

/// The preview column of a workspace: the `PDFPanel`, wired to this window's editor.
struct WorkspacePreview: View {
    @Environment(WorkspaceModel.self) private var workspace
    @Environment(ProjectLibrary.self) private var library
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        @Bindable var workspace = workspace

        PDFPanel(
            project: workspace.project,
            preview: workspace.preview,
            drawer: $workspace.drawer,
            actions: actions
        )
    }

    private var actions: PreviewActions {
        let workspace = workspace
        let projectPath = workspace.project.id
        // SyncTeX only exists for TeX; a Markdown preview has nothing to jump between.
        let hasSyncTeX = workspace.project.settings.mode == .tex
        return PreviewActions(
            goToPDF: hasSyncTeX ? { workspace.syncPDFToCaret() } : nil,
            jumpToSource: hasSyncTeX ? { page, point in workspace.syncSource(pageIndex: page, point: point) } : nil,
            openDiagnostic: { diagnostic in
                if let file = diagnostic.file { workspace.open(path: file, line: diagnostic.line) }
            },
            exportPDF: { workspace.exportPDF() },
            fixWithAI: workspace.fixWithAIAction(catalog: library.agents),
            markdown: workspace.markdownActions,
            openInWindow: { openWindow(id: "preview", value: projectPath) },
            openFullScreen: {
                library.fullScreenPreviewPath = projectPath
                openWindow(id: "preview", value: projectPath)
            },
            undo: { NSApp.sendAction(Selector(("undo:")), to: nil, from: nil) },
            redo: { NSApp.sendAction(Selector(("redo:")), to: nil, from: nil) }
        )
    }
}
