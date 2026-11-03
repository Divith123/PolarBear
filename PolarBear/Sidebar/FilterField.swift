//
//  FilterField.swift
//  PolarBear
//

import SwiftUI

struct FilterField: View {
    @Binding var text: String
    var prompt: LocalizedStringKey = "Filter files"

    var body: some View {
        HStack(spacing: AppTheme.Spacing.s) {
            Image(systemName: "magnifyingglass")
                .imageScale(.small)
                .foregroundStyle(AppTheme.textTertiary)
                .accessibilityHidden(true)
            TextField(prompt, text: $text)
                .textFieldStyle(.plain)
                .font(AppTheme.Typography.rowDetail)
                .foregroundStyle(AppTheme.textPrimary)
                .focusEffectDisabled()
        }
        .padding(.horizontal, AppTheme.Spacing.m)
        .frame(height: AppTheme.Metrics.filterFieldHeight)
        .background(AppTheme.controlFill, in: .rect(cornerRadius: AppTheme.Radius.row))
    }
}
