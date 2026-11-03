//
//  DocumentModeMenu.swift
//  PolarBear
//

import SwiftUI

/// The "TeX ⌄" dropdown at the top of the sidebar. Choosing Markdown turns the whole project
/// into a Markdown project: Markdown editing, outline, preview, download and copy.
struct DocumentModeMenu: View {
    @Environment(WorkspaceModel.self) private var workspace

    var body: some View {
        let current = workspace.project.settings.mode

        Menu {
            ForEach(DocumentMode.allCases) { mode in
                Button {
                    workspace.switchMode(mode)
                } label: {
                    if mode == current {
                        Label(mode.title, systemImage: "checkmark")
                    } else {
                        Text(verbatim: mode.title)
                    }
                }
            }
        } label: {
            HStack(spacing: AppTheme.Spacing.xs) {
                Text(verbatim: current.title)
                    .font(AppTheme.Typography.section)
                    .foregroundStyle(AppTheme.textPrimary)
                Image(systemName: "chevron.down")
                    .imageScale(.small)
                    .foregroundStyle(AppTheme.iconSecondary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, AppTheme.Spacing.m)
            .frame(height: AppTheme.Metrics.brandLogo)
            .contentShape(.rect(cornerRadius: AppTheme.Radius.control))
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .accessibilityLabel("Document type: \(current.title)")
        .help("Switch between TeX and Markdown")
    }
}
