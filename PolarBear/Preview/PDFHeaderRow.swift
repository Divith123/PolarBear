//
//  PDFHeaderRow.swift
//  PolarBear
//

import SwiftUI

struct PDFHeaderRow: View {
    let project: Project
    let preview: PreviewController
    @Binding var drawer: DrawerTab?
    let actions: PreviewActions
    let showsPager: Bool
    let showsZoomTitle: Bool

    var body: some View {
        HStack(spacing: 0) {
            CompiledStatus(project: project, drawer: $drawer, fix: actions.fixWithAI)

            Spacer(minLength: AppTheme.Spacing.l)

            if showsPager {
                PagerLabel(preview: preview)
                    .padding(.trailing, AppTheme.Spacing.xxl * 2)
            }

            PDFZoomMenu(preview: preview, showsTitle: showsZoomTitle)

            Group {
                if let markdown = actions.markdown {
                    MarkdownDownloadMenu(actions: markdown, hasPDF: project.build.publishedPDF != nil)
                } else {
                    IconButton(
                        title: "Download PDF",
                        systemImage: "arrow.down.circle",
                        tint: AppTheme.textPrimary,
                        action: actions.exportPDF
                    )
                    .disabled(project.build.publishedPDF == nil)
                }
            }
            .padding(.leading, AppTheme.Spacing.m)

            PDFMoreMenu(project: project, preview: preview, drawer: $drawer, actions: actions)
        }
        .padding(.horizontal, AppTheme.Spacing.xl)
        .frame(height: AppTheme.Metrics.barHeight)
        .background { WindowDragArea() }
    }
}
