//
//  PagerLabel.swift
//  PolarBear
//

import SwiftUI

/// "01 of 12": the page at the top of the preview and how many there are.
struct PagerLabel: View {
    let preview: PreviewController

    private let twoDigits = IntegerFormatStyle<Int>.number.precision(.integerLength(2...))

    var body: some View {
        HStack(spacing: AppTheme.Spacing.m) {
            Text(preview.pageCount == 0 ? 0 : preview.pageIndex + 1, format: twoDigits)
                .font(AppTheme.Typography.row)
                .foregroundStyle(AppTheme.textPrimary)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(AppTheme.textTertiary)
                        .frame(height: 1)
                        .offset(y: AppTheme.Spacing.s)
                }
            Text("of \(preview.pageCount, format: twoDigits)")
                .font(AppTheme.Typography.tab)
                .foregroundStyle(AppTheme.textTertiary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Page \(preview.pageIndex + 1) of \(preview.pageCount)")
    }
}
