//
//  WelcomeMain.swift
//  PolarBear
//

import SwiftUI

/// The right side of the welcome screen.
struct WelcomeMain: View {
    @Environment(WindowState.self) private var window
    @Environment(ProjectLibrary.self) private var library

    var body: some View {
        VStack(spacing: AppTheme.Spacing.xxl) {
            Image(.polarBearArtwork)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(maxWidth: AppTheme.Metrics.emptyStateArtworkWidth)
                .clipShape(.rect(cornerRadius: AppTheme.Radius.artwork))
                .accessibilityHidden(true)

            VStack(spacing: AppTheme.Spacing.s) {
                Text("PolarBear")
                    .font(AppTheme.Typography.welcomeTitle)
                    .foregroundStyle(AppTheme.textPrimary)
                Text("LaTeX on your Mac. Your files, your engine, your agents.")
                    .font(AppTheme.Typography.welcomeSubtitle)
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: AppTheme.Spacing.m) {
                WelcomeAction(title: "Open Folder…", systemImage: "folder", isProminent: true, action: openFolder)
                WelcomeAction(title: "New Project…", systemImage: "plus.square") { window.sheet = .newProject }
                WelcomeAction(title: "Migrate from Prism…", systemImage: "square.and.arrow.down", action: importArchive)
            }

            ToolchainCard()
        }
        .frame(maxWidth: AppTheme.Metrics.welcomeContentWidth)
        .padding(AppTheme.Spacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .top) {
            Color.clear
                .frame(height: AppTheme.Metrics.barHeight)
                .background { WindowDragArea() }
        }
    }

    private func openFolder() {
        Task { await window.openFolderFromPanel(library: library) }
    }

    private func importArchive() {
        guard let url = FilePanels.chooseArchive(message: String(localized: "Choose a project archive (.zip or .tar.gz).")) else { return }
        window.sheet = .importProject(url)
    }
}
