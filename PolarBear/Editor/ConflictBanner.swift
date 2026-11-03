//
//  ConflictBanner.swift
//  PolarBear
//

import SwiftUI

/// "main.tex changed on disk": the file was modified by another program while it also had
/// unsaved edits here. Nothing is overwritten until the user decides.
struct ConflictBanner: View {
    let file: ProjectFile
    let project: Project

    var body: some View {
        HStack(spacing: AppTheme.Spacing.l) {
            Image(systemName: "exclamationmark.arrow.triangle.2.circlepath")
                .accessibilityHidden(true)
            Text("“\(file.name)” was changed outside PolarBear.")
                .lineLimit(1)
            Spacer(minLength: AppTheme.Spacing.m)
            Button("Load from Disk") {
                file.resolveConflictLoadingDisk(stamp: FileIO.stamp(of: project.absoluteURL(for: file.path)) ?? .none)
            }
            .underline()
            Button("Keep Mine") {
                file.resolveConflictKeepingMine()
                Task { await project.saveDirtyFiles(triggersBuild: true) }
            }
            .underline()
        }
        .buttonStyle(.plain)
        .font(AppTheme.Typography.rowDetail)
        .foregroundStyle(AppTheme.warning)
        .padding(.horizontal, AppTheme.Spacing.xl)
        .padding(.vertical, AppTheme.Spacing.m)
        .background(AppTheme.warningFill)
        .overlay(alignment: .bottom) {
            Rectangle().fill(AppTheme.warningStroke).frame(height: 1)
        }
    }
}
