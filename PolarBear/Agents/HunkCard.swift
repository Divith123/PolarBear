//
//  HunkCard.swift
//  PolarBear
//

import SwiftUI

/// A hunk with the two decisions: keep it, or undo it.
struct HunkCard: View {
    let hunk: TextDiff.Hunk
    let keep: () -> Void
    let undo: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.s) {
            DiffHunkView(hunk: hunk)

            HStack(spacing: AppTheme.Spacing.m) {
                Spacer(minLength: 0)
                Button("Undo", action: undo)
                    .foregroundStyle(AppTheme.textSecondary)
                Button("Keep", action: keep)
                    .foregroundStyle(AppTheme.addedText)
            }
            .buttonStyle(.plain)
            .font(AppTheme.Typography.rowDetail)
        }
    }
}
