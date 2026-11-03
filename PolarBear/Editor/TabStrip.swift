//
//  TabStrip.swift
//  PolarBear
//

import SwiftUI

/// Horizontally scrolling tabs that follow the active one, like VS Code. The strip is only as
/// wide as its tabs, so the empty space after it still drags the window.
struct TabStrip: View {
    @Environment(WorkspaceModel.self) private var workspace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var contentWidth: CGFloat = 0
    @State private var viewportWidth: CGFloat = 0

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(spacing: AppTheme.Spacing.s) {
                    ForEach(workspace.openFiles) { file in
                        TabItem(
                            file: file,
                            isActive: workspace.activeID == file.id,
                            activate: workspace.activate,
                            close: workspace.close,
                            rename: { workspace.promptRename($0.path) }
                        )
                        .id(file.id)
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.xxs)
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { contentWidth = $0 }
            }
            .scrollIndicators(.hidden)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { viewportWidth = $0 }
            .mask { TabStripFade(isOverflowing: contentWidth > viewportWidth + 1) }
            .onChange(of: workspace.activeID) { _, id in
                scroll(to: id, with: proxy)
            }
            .onChange(of: workspace.openTabIDs) {
                scroll(to: workspace.activeID, with: proxy)
            }
        }
        .frame(maxWidth: contentWidth > 0 ? contentWidth : .infinity, alignment: .leading)
        .frame(height: AppTheme.Metrics.tabHeight + AppTheme.Spacing.m)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Open files")
    }

    private func scroll(to id: ProjectFile.ID?, with proxy: ScrollViewProxy) {
        guard let id else { return }
        withAnimation(reduceMotion ? nil : AppTheme.Timing.scroll) {
            proxy.scrollTo(id, anchor: .center)
        }
    }
}
