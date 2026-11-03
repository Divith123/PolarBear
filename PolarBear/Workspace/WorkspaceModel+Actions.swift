//
//  WorkspaceModel+Actions.swift
//  PolarBear
//

import SwiftUI

/// Actions that reach outside the window: Finder, save panels, archives.
extension WorkspaceModel {
    func revealProjectInFinder() {
        NSWorkspace.shared.activateFileViewerSelecting([project.root])
    }

    func reveal(inFinder path: String) {
        NSWorkspace.shared.activateFileViewerSelecting([project.absoluteURL(for: path)])
    }

    /// Opens a non-text file (an image, a PDF) with the app macOS picks for it.
    func openExternally(_ asset: ProjectAsset) {
        NSWorkspace.shared.open(project.absoluteURL(for: asset.path))
    }

    func exportPDF() {
        guard project.build.publishedPDF != nil else { return }
        let stem = project.resolvedRootFile.map(ProjectPath.stem(of:)) ?? project.name
        guard let destination = FilePanels.chooseSaveLocation(
            suggestedName: stem + ".pdf",
            message: String(localized: "Choose where to save the PDF.")
        ) else { return }
        do {
            try project.exportPDF(to: destination)
            NSWorkspace.shared.activateFileViewerSelecting([destination])
        } catch {
            report(error)
        }
    }
}
