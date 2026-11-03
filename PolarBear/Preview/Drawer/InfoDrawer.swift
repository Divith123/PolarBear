//
//  InfoDrawer.swift
//  PolarBear
//

import SwiftUI

/// The drawer that slides in over the preview, with four tabs: problems, logs, project info
/// and versions.
struct InfoDrawer: View {
    let project: Project
    let preview: PreviewController
    let tab: DrawerTab
    let actions: PreviewActions
    let select: (DrawerTab) -> Void
    let close: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            DrawerTabBar(tab: tab, errorCount: project.build.errorCount, select: select, close: close)

            Group {
                switch tab {
                case .problems:
                    ProblemsTab(build: project.build, open: actions.openDiagnostic, fix: actions.fixWithAI)
                case .log:
                    LogTab(build: project.build)
                case .stats:
                    StatsTab(project: project, pageCount: preview.pageCount)
                case .history:
                    HistoryTab(project: project)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(width: AppTheme.Metrics.drawerWidth)
        .frame(maxHeight: .infinity)
        .background(AppTheme.appBackground)
        .overlay(alignment: .leading) {
            Rectangle().fill(AppTheme.divider).frame(width: 1)
        }
    }
}
