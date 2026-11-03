//
//  RecentRow.swift
//  PolarBear
//

import SwiftUI

struct RecentRow: View {
    let recent: RecentProject
    let open: (RecentProject) -> Void
    let remove: (RecentProject) -> Void
    let reveal: (RecentProject) -> Void

    var body: some View {
        Button {
            open(recent)
        } label: {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                Text(recent.name)
                    .font(AppTheme.Typography.row)
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)
                Text(recent.displayPath)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.textTertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .padding(.horizontal, AppTheme.Spacing.l)
            .padding(.vertical, AppTheme.Spacing.s)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .rowHighlight(isSelected: false)
        .contextMenu {
            Button("Open") { open(recent) }
            Button("Show in Finder") { reveal(recent) }
            Divider()
            Button("Remove from List") { remove(recent) }
        }
    }
}
