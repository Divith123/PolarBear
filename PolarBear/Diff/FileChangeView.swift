//
//  FileChangeView.swift
//  PolarBear
//

import SwiftUI

/// A file's name with its +/− counts, and all its hunks underneath.
struct FileChangeView: View {
    let change: FileChange

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.m) {
            HStack(spacing: AppTheme.Spacing.m) {
                Image(systemName: symbol)
                    .foregroundStyle(AppTheme.iconSecondary)
                    .accessibilityHidden(true)
                Text(change.path)
                    .font(AppTheme.Typography.row)
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.head)
                Spacer(minLength: 0)
                DiffCounts(added: change.added, removed: change.removed)
            }

            ForEach(change.hunks) { hunk in
                DiffHunkView(hunk: hunk)
            }
        }
    }

    private var symbol: String {
        switch change.status {
        case .added: "plus.circle"
        case .modified: "pencil.circle"
        case .deleted: "minus.circle"
        }
    }
}
