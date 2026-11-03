//
//  SidebarHeader.swift
//  PolarBear
//

import SwiftUI

/// Brand, project picker and the Files / Chats row.
struct SidebarHeader: View {
    @Binding var isSearching: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.l) {
            SidebarBrandRow {
                DocumentModeMenu()
            }
            ProjectPickerRow()
            SidebarTabsRow(isSearching: $isSearching)
        }
        .padding(.horizontal, AppTheme.Spacing.xl)
        .padding(.top, AppTheme.Spacing.xxs)
    }
}
