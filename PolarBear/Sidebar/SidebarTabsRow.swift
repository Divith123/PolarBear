//
//  SidebarTabsRow.swift
//  PolarBear
//

import SwiftUI

/// Files / Chats tabs plus the filter and new-file buttons, over a hairline.
struct SidebarTabsRow: View {
    @Environment(WorkspaceModel.self) private var workspace
    @Binding var isSearching: Bool

    var body: some View {
        HStack(spacing: AppTheme.Spacing.l) {
            ForEach(SidebarTab.allCases, id: \.self) { tab in
                SidebarTabButton(
                    tab: tab,
                    isSelected: workspace.sidebarTab == tab,
                    select: workspace.selectSidebarTab
                )
            }

            Spacer(minLength: 0)

            IconButton(
                title: "Filter Files",
                systemImage: "magnifyingglass",
                tint: isSearching ? AppTheme.textPrimary : AppTheme.iconTertiary
            ) {
                isSearching.toggle()
            }

            AddMenuButton(
                newFile: { workspace.promptNewFile() },
                newFolder: { workspace.promptNewFolder() },
                addFiles: { workspace.addFilesFromPanel() }
            )
        }
        .padding(.leading, AppTheme.Spacing.xs)
        .frame(height: AppTheme.Metrics.sidebarTabHeight)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AppTheme.hairlineFaint)
                .frame(height: 1)
        }
    }
}
