//
//  PDFMoreMenu.swift
//  PolarBear
//

import SwiftUI

/// The "…" menu of the preview: other windows, text view, Finder, logs.
struct PDFMoreMenu: View {
    let project: Project
    @Bindable var preview: PreviewController
    @Binding var drawer: DrawerTab?
    let actions: PreviewActions

    var body: some View {
        Menu {
            if let openInWindow = actions.openInWindow {
                Button("Open in New Window", action: openInWindow)
            }
            if let openFullScreen = actions.openFullScreen {
                Button("Open in Full Screen", action: openFullScreen)
            }
            Toggle("Show as Text", isOn: $preview.isTextMode)
                .disabled(project.build.publishedPDF == nil)

            Divider()

            Button("Show PDF in Finder") {
                if let pdf = project.build.publishedPDF {
                    NSWorkspace.shared.activateFileViewerSelecting([pdf])
                }
            }
            .disabled(project.build.publishedPDF == nil)
            Button("Show Logs") { drawer = .log }
        } label: {
            Image(systemName: "ellipsis")
                .foregroundStyle(AppTheme.textPrimary)
                .frame(width: AppTheme.Metrics.iconButton, height: AppTheme.Metrics.iconButton)
                .contentShape(.rect)
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .padding(.leading, AppTheme.Spacing.xs)
        .accessibilityLabel("More Options")
        .help("More Options")
    }
}
