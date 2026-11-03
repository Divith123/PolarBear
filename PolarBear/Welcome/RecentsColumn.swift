//
//  RecentsColumn.swift
//  PolarBear
//

import SwiftUI

/// The left column of the welcome screen: the brand and the recent projects.
struct RecentsColumn: View {
    @Environment(WindowState.self) private var window
    @Environment(ProjectLibrary.self) private var library
    @State private var query = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Color.clear
                .frame(height: AppTheme.Metrics.barHeight)
                .background { WindowDragArea() }

            VStack(alignment: .leading, spacing: AppTheme.Spacing.l) {
                SidebarBrandRow()
                FilterField(text: $query, prompt: "Filter projects")
            }
            .padding(.horizontal, AppTheme.Spacing.xl)

            Text("Recent Projects")
                .font(AppTheme.Typography.section)
                .foregroundStyle(AppTheme.textPrimary)
                .padding(.horizontal, AppTheme.Spacing.xl + AppTheme.Spacing.xs)
                .padding(.top, AppTheme.Spacing.xxl)
                .padding(.bottom, AppTheme.Spacing.s)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                    ForEach(visibleRecents) { recent in
                        RecentRow(
                            recent: recent,
                            open: open,
                            remove: library.forget,
                            reveal: reveal
                        )
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.xl)
            }
            .scrollIndicators(.hidden)
            .overlay {
                if library.recents.isEmpty {
                    ContentUnavailableView {
                        Label("No Recent Projects", systemImage: "clock")
                    } description: {
                        Text("Projects you open appear here.")
                    }
                } else if visibleRecents.isEmpty {
                    ContentUnavailableView.search(text: query)
                }
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(AppTheme.appBackground)
    }

    private var visibleRecents: [RecentProject] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return library.recents }
        return library.recents.filter { $0.name.localizedStandardContains(trimmed) }
    }

    private func open(_ recent: RecentProject) {
        Task { await window.open(recent, library: library) }
    }

    private func reveal(_ recent: RecentProject) {
        NSWorkspace.shared.activateFileViewerSelecting([URL(filePath: recent.path)])
    }
}
