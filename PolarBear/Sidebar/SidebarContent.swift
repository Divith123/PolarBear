//
//  SidebarContent.swift
//  PolarBear
//

import SwiftUI

/// The part of the sidebar that follows the Files / Chats selection.
struct SidebarContent: View {
    @Environment(WorkspaceModel.self) private var workspace
    @Binding var query: String
    let isSearching: Bool

    var body: some View {
        Group {
            switch workspace.sidebarTab {
            case .files:
                FilesList(query: $query, isSearching: isSearching)
            case .chats:
                ChatsList()
            }
        }
        .padding(.horizontal, AppTheme.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}
