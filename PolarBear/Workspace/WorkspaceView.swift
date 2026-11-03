//
//  WorkspaceView.swift
//  PolarBear
//

import SwiftUI

/// Sidebar | editor | PDF preview, edge to edge, separated by draggable 1-pt dividers.
///
/// The preview undocks on narrow windows (it stays reachable as a sheet from the editor's
/// tab bar), so no feature disappears at small sizes.
///
/// Each split pane is hosted in its own AppKit view with its own safe area, so every pane
/// ignores the (hidden) title bar's top inset itself — the window-level modifier cannot.
struct WorkspaceView: View {
    @Environment(WorkspaceModel.self) private var workspace
    @State private var windowWidth = AppTheme.Metrics.defaultWindowWidth

    var body: some View {
        HSplitView {
            if workspace.sidebarVisible {
                SidebarView()
                    .frame(
                        minWidth: AppTheme.Metrics.sidebarMin,
                        idealWidth: AppTheme.Metrics.sidebarIdeal,
                        maxWidth: AppTheme.Metrics.sidebarMax
                    )
                    .ignoresSafeArea(edges: .top)
            }

            if workspace.showsEditor {
                EditorPanel()
                    .frame(
                        minWidth: AppTheme.Metrics.editorMin,
                        idealWidth: AppTheme.Metrics.editorIdeal,
                        maxWidth: .infinity
                    )
                    .ignoresSafeArea(edges: .top)
            }

            if workspace.showsPreview && (isPreviewDocked || !workspace.showsEditor) {
                WorkspacePreview()
                    .frame(
                        minWidth: AppTheme.Metrics.previewMin,
                        idealWidth: AppTheme.Metrics.previewIdeal,
                        maxWidth: .infinity
                    )
                    .ignoresSafeArea(edges: .top)
            }
        }
        .onGeometryChange(for: Double.self) { proxy in
            Double(proxy.size.width)
        } action: { width in
            windowWidth = width
        }
        .onChange(of: isPreviewDocked, initial: true) { _, isDocked in
            workspace.isPreviewDocked = isDocked
        }
    }

    private var isPreviewDocked: Bool {
        let sidebar = workspace.sidebarVisible ? AppTheme.Metrics.sidebarMin : 0
        return windowWidth >= sidebar + AppTheme.Metrics.editorMin + AppTheme.Metrics.previewMin
    }
}

#Preview {
    WorkspaceView()
        .environment(WorkspaceModel.preview)
        .frame(width: AppTheme.Metrics.defaultWindowWidth, height: AppTheme.Metrics.defaultWindowHeight)
}
