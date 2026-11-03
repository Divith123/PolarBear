//
//  VersionDiffView.swift
//  PolarBear
//

import SwiftUI

/// What changed in one version, file by file, with the option to go back to it.
struct VersionDiffView: View {
    let project: Project
    let version: VersionRecord
    let restore: (VersionRecord) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var changes: [FileChange]?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                    Text("v\(version.number)  \(version.title)")
                        .font(AppTheme.Typography.section)
                        .foregroundStyle(AppTheme.textPrimary)
                    Text(version.date, format: .dateTime.day().month().year().hour().minute())
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.textTertiary)
                }
                Spacer()
                Button("Restore This Version…") {
                    dismiss()
                    restore(version)
                }
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(AppTheme.Spacing.xl)

            Divider().overlay(AppTheme.hairlineFaint)

            if let changes {
                if changes.isEmpty {
                    ContentUnavailableView("No Changes", systemImage: "equal.circle")
                        .foregroundStyle(AppTheme.textSecondary)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: AppTheme.Spacing.xxl) {
                            ForEach(changes) { change in
                                FileChangeView(change: change)
                            }
                        }
                        .padding(AppTheme.Spacing.xl)
                    }
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 640, minHeight: 480)
        .background(AppTheme.appBackground)
        .appAppearance()
        .task {
            changes = await project.history.changes(of: version)
        }
    }
}
