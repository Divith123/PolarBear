//
//  SidebarWindowRow.swift
//  PolarBear
//

import SwiftUI

/// First row of the sidebar. The window buttons sit on its left (placed by
/// `WindowChromeController`); the sidebar toggle sits on its right. Empty parts drag the window.
struct SidebarWindowRow: View {
    @Environment(WorkspaceModel.self) private var workspace

    var body: some View {
        IconButton(
            title: "Hide Sidebar",
            systemImage: "sidebar.left",
            tint: AppTheme.iconSecondary,
            action: workspace.toggleSidebar
        )
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.trailing, AppTheme.Spacing.xl)
        .frame(height: AppTheme.Metrics.barHeight)
        .background { WindowDragArea() }
    }
}
