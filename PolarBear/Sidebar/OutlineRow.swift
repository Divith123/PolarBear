//
//  OutlineRow.swift
//  PolarBear
//

import SwiftUI

struct OutlineRow: View {
    let item: OutlineItem
    let reveal: (Int) -> Void

    var body: some View {
        Button {
            reveal(item.line)
        } label: {
            Text(item.title)
                .font(AppTheme.Typography.rowDetail)
                .foregroundStyle(AppTheme.textSecondary)
                .lineLimit(1)
                .padding(.leading, AppTheme.Spacing.xxl + Double(item.level) * AppTheme.Spacing.m)
                .frame(maxWidth: .infinity, minHeight: AppTheme.Metrics.outlineRowHeight, alignment: .leading)
        }
        .buttonStyle(.plain)
        .rowHighlight(isSelected: false, cornerRadius: AppTheme.Radius.badge)
    }
}
