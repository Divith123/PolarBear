//
//  PreviewWindowView.swift
//  PolarBear
//

import SwiftUI

/// The preview in a window of its own ("Open in New Window", "Open in Full Screen"). It shows
/// the same project and the same published PDF as the main window.
struct PreviewWindowView: View {
    let projectPath: String?
    @Environment(ProjectLibrary.self) private var library

    var body: some View {
        Group {
            if let projectPath, let project = library.openProject(atPath: projectPath) {
                PreviewWindowContent(project: project, wantsFullScreen: library.fullScreenPreviewPath == projectPath)
            } else {
                ContentUnavailableView("Project Closed", systemImage: "doc.richtext")
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
        .frame(minWidth: AppTheme.Metrics.previewMin, minHeight: AppTheme.Metrics.minWindowHeight)
        .background(AppTheme.panelBackground)
        .appAppearance()
    }
}
