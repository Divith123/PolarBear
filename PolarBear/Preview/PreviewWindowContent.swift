//
//  PreviewWindowContent.swift
//  PolarBear
//

import SwiftUI

struct PreviewWindowContent: View {
    let project: Project
    let wantsFullScreen: Bool

    @Environment(ProjectLibrary.self) private var library
    @State private var preview: PreviewController
    @State private var drawer: DrawerTab?

    init(project: Project, wantsFullScreen: Bool) {
        self.project = project
        self.wantsFullScreen = wantsFullScreen
        self._preview = State(initialValue: PreviewController(zoom: PDFZoom(percent: project.settings.previewZoomPercent)))
    }

    var body: some View {
        PDFPanel(
            project: project,
            preview: preview,
            drawer: $drawer,
            actions: PreviewActions(exportPDF: exportPDF)
        )
        .navigationTitle("\(project.name) — Preview")
        .task {
            guard wantsFullScreen else { return }
            library.fullScreenPreviewPath = nil
            do {
                try await Task.sleep(for: .milliseconds(300))
            } catch {
                return
            }
            NSApp.keyWindow?.toggleFullScreen(nil)
        }
    }

    private func exportPDF() {
        guard project.build.publishedPDF != nil,
              let destination = FilePanels.chooseSaveLocation(
                  suggestedName: (project.resolvedRootFile.map(ProjectPath.stem(of:)) ?? project.name) + ".pdf",
                  message: String(localized: "Choose where to save the PDF.")
              ) else { return }
        try? project.exportPDF(to: destination)
    }
}
