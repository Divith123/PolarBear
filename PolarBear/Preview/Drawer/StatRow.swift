//
//  StatRow.swift
//  PolarBear
//

import SwiftUI

struct StatRow: View {
    let title: LocalizedStringKey
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .foregroundStyle(AppTheme.textSecondary)
            Spacer(minLength: AppTheme.Spacing.l)
            Text(value)
                .foregroundStyle(AppTheme.textPrimary)
                .monospacedDigit()
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .font(AppTheme.Typography.rowDetail)
        .frame(minHeight: AppTheme.Metrics.drawerRowHeight - AppTheme.Spacing.m)
        .accessibilityElement(children: .combine)
    }
}
