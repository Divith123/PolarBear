//
//  SidebarView.swift
//  PolarBear
//
//  The left column: window-button row, brand, project picker, Files / Chats, the file
//  tree, the document outline and the project footer.
//

import SwiftUI

struct SidebarView: View {
    @State private var isSearching = false
    @State private var query = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SidebarWindowRow()
            SidebarHeader(isSearching: $isSearching)
            SidebarContent(query: $query, isSearching: isSearching)
            OutlinePane()
            ProjectFooter()
        }
        .background(AppTheme.appBackground)
        .onChange(of: isSearching) { _, isSearching in
            if !isSearching { query = "" }
        }
    }
}

#Preview {
    SidebarView()
        .environment(WorkspaceModel.preview)
        .frame(width: AppTheme.Metrics.sidebarIdeal, height: AppTheme.Metrics.defaultWindowHeight)
}
