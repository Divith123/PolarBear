//
//  WorkspaceModel+SyncTeX.swift
//  PolarBear
//

import Foundation

/// Jumping between the source and the PDF.
extension WorkspaceModel {
    /// "Go to PDF": show the part of the PDF that the line under the caret produced.
    func syncPDFToCaret() {
        guard let file = activeFile else { return }
        syncPDF(file: file, line: caretLine)
    }

    /// ⌘-click in the editor: the same for the clicked line.
    func syncPDF(file: ProjectFile, line: Int) {
        Task { await project.sync.showPDF(for: file.path, line: line, in: preview) }
    }

    /// ⌘-click in the PDF: open the source line that produced the clicked spot.
    func syncSource(pageIndex: Int, point: CGPoint) {
        Task {
            guard let hit = await project.sync.sourceLocation(pageIndex: pageIndex, point: point, in: preview) else { return }
            open(path: hit.file, line: hit.line)
        }
    }
}
