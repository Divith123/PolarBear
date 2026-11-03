//
//  TemplateTile.swift
//  PolarBear
//

import SwiftUI

struct TemplateTile: View {
    let template: ProjectTemplate
    let isSelected: Bool
    let select: (ProjectTemplate) -> Void

    var body: some View {
        Button {
            select(template)
        } label: {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.s) {
                Image(systemName: template.symbol)
                    .font(.title2)
                    .foregroundStyle(isSelected ? AppTheme.textPrimary : AppTheme.iconSecondary)
                    .frame(height: AppTheme.Spacing.xxl + AppTheme.Spacing.m, alignment: .leading)
                    .accessibilityHidden(true)
                Text(template.name)
                    .font(AppTheme.Typography.row)
                    .foregroundStyle(AppTheme.textPrimary)
                Text(template.summary)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.textTertiary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
            }
            .padding(AppTheme.Spacing.l)
            .frame(maxWidth: .infinity, minHeight: AppTheme.Metrics.templateTileWidth * 0.8, alignment: .topLeading)
            .background(isSelected ? AppTheme.selectionFill : AppTheme.controlFill, in: .rect(cornerRadius: AppTheme.Radius.control))
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.Radius.control, style: .continuous)
                    .stroke(isSelected ? AppTheme.tabBorder : AppTheme.hairline, lineWidth: 1)
            }
            .contentShape(.rect(cornerRadius: AppTheme.Radius.control))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
