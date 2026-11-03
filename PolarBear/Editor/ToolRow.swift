//
//  ToolRow.swift
//  PolarBear
//

import SwiftUI

/// One program: found (with its path) or not.
struct ToolRow: View {
    let name: String
    let url: URL?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: AppTheme.Spacing.m) {
            Image(systemName: url == nil ? "minus.circle" : "checkmark.circle.fill")
                .foregroundStyle(url == nil ? AppTheme.textTertiary : AppTheme.success)
                .accessibilityHidden(true)
            Text(verbatim: name)
                .foregroundStyle(AppTheme.textPrimary)
            Spacer(minLength: AppTheme.Spacing.m)
            if let url {
                Text(url.path(percentEncoded: false))
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.textTertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            } else {
                Text("Not found")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.textTertiary)
            }
        }
        .font(AppTheme.Typography.rowDetail)
        .accessibilityElement(children: .combine)
    }
}
