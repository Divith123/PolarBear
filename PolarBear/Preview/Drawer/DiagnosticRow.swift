//
//  DiagnosticRow.swift
//  PolarBear
//

import SwiftUI

struct DiagnosticRow: View {
    let diagnostic: Diagnostic
    let open: ((Diagnostic) -> Void)?

    var body: some View {
        Button {
            open?(diagnostic)
        } label: {
            HStack(alignment: .top, spacing: AppTheme.Spacing.m) {
                Image(systemName: symbol)
                    .foregroundStyle(tint)
                    .frame(width: AppTheme.Spacing.xxl)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                    Text(diagnostic.message)
                        .font(AppTheme.Typography.rowDetail)
                        .foregroundStyle(AppTheme.textPrimary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(3)

                    if let location {
                        Text(location)
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(AppTheme.textTertiary)
                            .lineLimit(1)
                            .truncationMode(.head)
                    }
                    if let context = diagnostic.context, !context.isEmpty {
                        Text(context)
                            .font(AppTheme.Typography.codeSmall)
                            .foregroundStyle(AppTheme.textSecondary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, AppTheme.Spacing.m)
            .padding(.vertical, AppTheme.Spacing.s)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .rowHighlight(isSelected: false)
        .disabled(diagnostic.file == nil || open == nil)
    }

    private var location: String? {
        guard let file = diagnostic.file else { return nil }
        guard let line = diagnostic.line else { return file }
        return "\(file):\(line)"
    }

    private var symbol: String {
        switch diagnostic.severity {
        case .error: "xmark.octagon.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .info: "info.circle"
        }
    }

    private var tint: Color {
        switch diagnostic.severity {
        case .error: AppTheme.danger
        case .warning: AppTheme.warning
        case .info: AppTheme.iconTertiary
        }
    }
}
