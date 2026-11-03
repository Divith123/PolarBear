//
//  EditorPanel.swift
//  PolarBear
//
//  The editor column: tab bar, the code editor (or an empty state) and the composer.
//

import SwiftUI

struct EditorPanel: View {
    @Environment(WorkspaceModel.self) private var workspace

    var body: some View {
        VStack(spacing: 0) {
            EditorTabBar()
            EditorContent()
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if workspace.showsAssistant {
                ComposerBar()
            }
        }
        .background(AppTheme.panelBackground)
    }
}

#Preview {
    EditorPanel()
        .environment(WorkspaceModel.preview)
        .frame(width: 700, height: AppTheme.Metrics.defaultWindowHeight)
}
