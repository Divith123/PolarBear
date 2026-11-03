//
//  HistoryTab.swift
//  PolarBear
//

import SwiftUI
import os

/// The project's versions, newest first, each with the lines it added and removed.
struct HistoryTab: View {
    let project: Project

    @State private var inspected: VersionRecord?
    @State private var versionToRestore: VersionRecord?

    var body: some View {
        let versions = project.history.versions

        VStack(spacing: 0) {
            HStack {
                Text("Versions")
                    .font(AppTheme.Typography.section)
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer(minLength: 0)
                Button("Save Version") {
                    Task { await project.saveVersion() }
                }
                .buttonStyle(.plain)
                .font(AppTheme.Typography.rowDetail)
                .foregroundStyle(AppTheme.link)
            }
            .padding(.horizontal, AppTheme.Spacing.xl)
            .frame(height: AppTheme.Metrics.drawerRowHeight)

            if versions.isEmpty {
                ContentUnavailableView {
                    Label("No Versions Yet", systemImage: "clock.arrow.circlepath")
                } description: {
                    Text("Versions are recorded when you save, and when editing pauses.")
                }
                .foregroundStyle(AppTheme.textSecondary)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                        ForEach(versions) { version in
                            VersionRow(version: version, inspect: { inspected = $0 }, restore: { versionToRestore = $0 })
                        }
                        Text("Showing all ^[\(versions.count) version](inflect: true)")
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(AppTheme.textTertiary)
                            .padding(AppTheme.Spacing.l)
                    }
                    .padding(.horizontal, AppTheme.Spacing.m)
                }
                .scrollIndicators(.hidden)
            }
        }
        .sheet(item: $inspected) { version in
            VersionDiffView(project: project, version: version) { versionToRestore = $0 }
        }
        .confirmationDialog("Restore this version?", item: $versionToRestore) { version in
            Button("Restore v\(version.number)", role: .destructive) { restore(version) }
        } message: { version in
            Text("The project goes back to “\(version.title)”. The current state is saved as a version first, so you can undo this.")
        }
    }

    private func restore(_ version: VersionRecord) {
        Task {
            do {
                try await project.restore(version)
            } catch {
                Log.history.error("Restore failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}
