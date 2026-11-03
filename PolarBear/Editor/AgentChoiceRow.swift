//
//  AgentChoiceRow.swift
//  PolarBear
//

import SwiftUI

struct AgentChoiceRow: View {
    let kind: AgentKind
    let isInstalled: Bool
    let isSelected: Bool
    let select: () -> Void

    var body: some View {
        Button(action: select) {
            HStack(spacing: AppTheme.Spacing.m) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : (isInstalled ? "circle" : "minus.circle"))
                    .foregroundStyle(isSelected ? AppTheme.success : AppTheme.iconTertiary)
                    .accessibilityHidden(true)
                Text(verbatim: kind.displayName)
                    .foregroundStyle(isInstalled ? AppTheme.textPrimary : AppTheme.textTertiary)
                Spacer(minLength: 0)
                Text(isInstalled ? "Found" : "Not installed")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.textTertiary)
            }
            .font(AppTheme.Typography.rowDetail)
            .padding(.horizontal, AppTheme.Spacing.m)
            .frame(maxWidth: .infinity, minHeight: AppTheme.Metrics.rowHeight, alignment: .leading)
        }
        .buttonStyle(.plain)
        .rowHighlight(isSelected: isSelected, cornerRadius: AppTheme.Radius.badge)
        .disabled(!isInstalled)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
