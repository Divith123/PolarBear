//
//  MarkdownDownloadMenu.swift
//  PolarBear
//

import SwiftUI

/// The download button of the preview header in a Markdown project: a menu with Markdown, PDF
/// and the copy formats instead of a single PDF button.
struct MarkdownDownloadMenu: View {
    let actions: MarkdownActions
    let hasPDF: Bool

    var body: some View {
        Menu {
            MarkdownExportItems(actions: actions, hasPDF: hasPDF)
        } label: {
            Image(systemName: "arrow.down.circle")
                .foregroundStyle(AppTheme.textPrimary)
                .frame(width: AppTheme.Metrics.iconButton, height: AppTheme.Metrics.iconButton)
                .contentShape(.rect)
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .accessibilityLabel("Download or Copy")
        .help("Download or Copy")
    }
}
