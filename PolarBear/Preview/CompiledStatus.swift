//
//  CompiledStatus.swift
//  PolarBear
//

import SwiftUI

/// The "Compiled ⌄" pill. It shows what the last build did and opens a menu: compile or stop,
/// open the drawer on a tab, choose the engine, switch automatic compiling on or off.
struct CompiledStatus: View {
    let project: Project
    @Binding var drawer: DrawerTab?
    let fix: FixWithAIAction?

    var body: some View {
        let build = project.build

        Menu {
            Button(build.isRunning ? "Stop" : "Compile") {
                if build.isRunning { build.cancel() } else { project.compile() }
            }
            if let fix, fix.hasProblems {
                Button("Fix with AI", systemImage: "sparkles", action: fix.perform)
                    .disabled(!fix.isAvailable)
            }
            Divider()
            ForEach(DrawerTab.allCases) { tab in
                Button {
                    drawer = tab
                } label: {
                    Label(tab.title, systemImage: tab.symbol)
                }
            }
            Divider()
            RealtimeToggle(project: project)
            RemoteImagesToggle(project: project)
            EngineMenu(project: project)
        } label: {
            HStack(spacing: AppTheme.Spacing.m) {
                BuildStatusLabel(status: build.status, isOutOfDate: project.isPDFOutOfDate && !project.settings.realtimeCompile)

                Rectangle()
                    .fill(AppTheme.hairlineStrong)
                    .frame(width: 1, height: AppTheme.Spacing.xxl - AppTheme.Spacing.xs)

                Image(systemName: "chevron.down")
                    .imageScale(.small)
                    .foregroundStyle(AppTheme.iconSecondary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, AppTheme.Spacing.l)
            .frame(height: AppTheme.Metrics.pillHeight)
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.Radius.pill, style: .continuous)
                    .stroke(AppTheme.hairlineStrong, lineWidth: 1)
            }
            .contentShape(.rect(cornerRadius: AppTheme.Radius.pill))
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .accessibilityLabel("Build status")
    }
}
