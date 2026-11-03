//
//  PDFPanel.swift
//  PolarBear
//
//  The preview: header controls, the real PDF, the floating page bar and the drawer with
//  problems, logs, project info and versions.
//

import SwiftUI

struct PDFPanel: View {
    let project: Project
    let preview: PreviewController
    @Binding var drawer: DrawerTab?
    let actions: PreviewActions

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            PDFHeader(project: project, preview: preview, drawer: $drawer, actions: actions)
            PDFContent(project: project, preview: preview, drawer: $drawer, actions: actions)
        }
        .overlay(alignment: .bottom) {
            if project.build.publishedPDF != nil, !preview.isTextMode {
                PDFFloatingBar(preview: preview, actions: actions)
                    .padding(.bottom, AppTheme.Spacing.l)
            }
        }
        .overlay(alignment: .trailing) {
            if let tab = drawer {
                InfoDrawer(
                    project: project,
                    preview: preview,
                    tab: tab,
                    actions: actions,
                    select: { drawer = $0 },
                    close: { drawer = nil }
                )
                .transition(.move(edge: .trailing))
            }
        }
        .animation(reduceMotion ? nil : AppTheme.Timing.disclosure, value: drawer)
        .background(AppTheme.panelBackground)
        .clipped()
    }
}

#Preview("Problems drawer") {
    PDFPanel(
        project: .preview,
        preview: PreviewController(),
        drawer: .constant(.problems),
        actions: PreviewActions(exportPDF: {})
    )
    .frame(width: AppTheme.Metrics.previewIdeal, height: 700)
}

#Preview("Empty") {
    PDFPanel(
        project: .preview,
        preview: PreviewController(),
        drawer: .constant(nil),
        actions: PreviewActions(exportPDF: {})
    )
    .frame(width: AppTheme.Metrics.previewIdeal, height: 700)
}
