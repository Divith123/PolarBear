//
//  DiffLineRow.swift
//  PolarBear
//

import SwiftUI

/// One line of a diff: old and new line numbers, a sign and the text, on a solid tint.
struct DiffLineRow: View {
    let line: TextDiff.Line

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            number(line.oldNumber)
            number(line.newNumber)
            Text(verbatim: sign)
                .foregroundStyle(textColor)
                .frame(width: AppTheme.Spacing.xxl)
            Text(verbatim: line.text.isEmpty ? " " : line.text)
                .foregroundStyle(textColor)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(AppTheme.Typography.codeSmall)
        .frame(minHeight: AppTheme.Metrics.diffLineHeight)
        .background(fill)
    }

    private func number(_ value: Int?) -> some View {
        Text(value.map(String.init) ?? "")
            .foregroundStyle(AppTheme.textTertiary)
            .frame(width: AppTheme.Spacing.xxl * 2, alignment: .trailing)
            .padding(.trailing, AppTheme.Spacing.xs)
    }

    private var sign: String {
        switch line.kind {
        case .added: "+"
        case .removed: "−"
        case .context: " "
        }
    }

    private var textColor: Color {
        switch line.kind {
        case .added: AppTheme.addedText
        case .removed: AppTheme.removedText
        case .context: AppTheme.textSecondary
        }
    }

    private var fill: Color {
        switch line.kind {
        case .added: AppTheme.addedFill
        case .removed: AppTheme.removedFill
        case .context: .clear
        }
    }
}
