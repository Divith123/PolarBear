//
//  WelcomeView.swift
//  PolarBear
//

import SwiftUI

/// What a window shows before a project is open: the recent projects and the three ways in —
/// open a folder, start from a template, bring a project over from another tool.
struct WelcomeView: View {
    var body: some View {
        HStack(spacing: 0) {
            RecentsColumn()
                .frame(width: AppTheme.Metrics.sidebarIdeal)

            Rectangle()
                .fill(AppTheme.divider)
                .frame(width: 1)

            WelcomeMain()
        }
        .background(AppTheme.panelBackground)
    }
}

#Preview {
    WelcomeView()
        .environment(WindowState())
        .environment(ProjectLibrary())
        .frame(width: 1100, height: 700)
}
