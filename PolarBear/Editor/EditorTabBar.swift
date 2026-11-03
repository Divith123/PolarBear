//
//  EditorTabBar.swift
//  PolarBear
//

import SwiftUI

/// First row of the editor column. When the sidebar is hidden the window buttons sit at its
/// left, so the content starts after `AppTheme.Metrics.trafficLightsReserve`.
struct EditorTabBar: View {
    @Environment(WorkspaceModel.self) private var workspace
    @Environment(WindowState.self) private var window

    var body: some View {
        HStack(spacing: AppTheme.Spacing.m) {
            if !workspace.sidebarVisible {
                IconButton(
                    title: "Show Sidebar",
                    systemImage: "sidebar.left",
                    tint: AppTheme.iconSecondary,
                    action: workspace.toggleSidebar
                )
            }

            IconButton(title: "New File", systemImage: "plus.circle") { workspace.promptNewFile() }

            TabStrip()

            Spacer(minLength: 0)

            if !workspace.isPreviewDocked {
                IconButton(
                    title: "Show Preview",
                    systemImage: "doc.richtext",
                    tint: AppTheme.iconSecondary,
                    action: workspace.presentPreview
                )
            }

            LayoutMenuButton(workspace: workspace)

            ToolsBadge()
        }
        .padding(.leading, leadingInset)
        .padding(.trailing, AppTheme.Spacing.l)
        .frame(height: AppTheme.Metrics.barHeight)
        .background { WindowDragArea() }
    }

    private var leadingInset: Double {
        if workspace.sidebarVisible || window.isFullScreen {
            AppTheme.Spacing.xl
        } else {
            AppTheme.Metrics.trafficLightsReserve
        }
    }
}
