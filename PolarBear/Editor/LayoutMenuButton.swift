//
//  LayoutMenuButton.swift
//  PolarBear
//

import SwiftUI

/// The panel-layout menu of the tab bar.
struct LayoutMenuButton: View {
    let workspace: WorkspaceModel

    var body: some View {
        Menu {
            LayoutToggles(workspace: workspace)
        } label: {
            Image(systemName: "rectangle.split.3x1")
                .foregroundStyle(AppTheme.iconSecondary)
                .frame(width: AppTheme.Metrics.iconButton, height: AppTheme.Metrics.iconButton)
                .contentShape(.rect)
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .accessibilityLabel("Layout")
        .help("Layout")
    }
}
