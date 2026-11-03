//
//  ShareMenuButton.swift
//  PolarBear
//

import SwiftUI

/// The white round button next to the project name. A local project has no collaborators to
/// invite, so sharing means handing over the files: reveal them, or export a PDF or a zip.
struct ShareMenuButton: View {
    let workspace: WorkspaceModel

    var body: some View {
        Menu {
            Button("Show in Finder") { workspace.revealProjectInFinder() }
            Button("Copy Project Path") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(workspace.project.id, forType: .string)
            }
            Divider()
            if let markdown = workspace.markdownActions {
                MarkdownExportItems(actions: markdown, hasPDF: workspace.project.build.publishedPDF != nil)
            } else {
                Button("Export PDF…") { workspace.exportPDF() }
                    .disabled(workspace.project.build.publishedPDF == nil)
            }
            Button("Export Project as Zip…") { workspace.exportArchive() }
        } label: {
            Image(systemName: "square.and.arrow.up")
                .foregroundStyle(AppTheme.onAccent)
                .frame(width: AppTheme.Metrics.avatar, height: AppTheme.Metrics.avatar)
                .background(AppTheme.accentInk, in: .circle)
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .accessibilityLabel("Share")
        .help("Share")
    }
}
