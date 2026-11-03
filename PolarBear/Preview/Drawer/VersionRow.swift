//
//  VersionRow.swift
//  PolarBear
//

import SwiftUI

struct VersionRow: View {
    let version: VersionRecord
    let inspect: (VersionRecord) -> Void
    let restore: (VersionRecord) -> Void

    var body: some View {
        Button {
            inspect(version)
        } label: {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                Text("v\(version.number)  \(version.title)")
                    .font(AppTheme.Typography.rowDetail)
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)
                HStack(spacing: AppTheme.Spacing.m) {
                    Text(version.date, format: .relative(presentation: .named))
                        .foregroundStyle(AppTheme.textTertiary)
                    DiffCounts(added: version.added, removed: version.removed)
                }
                .font(AppTheme.Typography.caption)
            }
            .padding(.horizontal, AppTheme.Spacing.m)
            .padding(.vertical, AppTheme.Spacing.s)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .rowHighlight(isSelected: false)
        .contextMenu {
            Button("View Changes") { inspect(version) }
            Button("Restore This Version…") { restore(version) }
        }
    }
}
