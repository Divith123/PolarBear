//
//  WorkspaceModel+Archive.swift
//  PolarBear
//

import SwiftUI

extension WorkspaceModel {
    /// Saves the project as a zip anywhere the user chooses (without PolarBear's own metadata).
    func exportArchive() {
        guard let destination = FilePanels.chooseSaveLocation(
            suggestedName: project.name + ".zip",
            message: String(localized: "Choose where to save the project archive.")
        ) else { return }
        let project = project
        Task {
            do {
                await project.saveDirtyFiles(triggersBuild: false)
                try await ArchiveTool.zip(folder: project.root, to: destination)
                NSWorkspace.shared.activateFileViewerSelecting([destination])
            } catch {
                report(error)
            }
        }
    }
}
