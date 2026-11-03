//
//  EffortChip.swift
//  PolarBear
//

import SwiftUI

struct EffortChip: View {
    let title: LocalizedStringKey
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(AppTheme.Typography.caption)
                .foregroundStyle(isSelected ? AppTheme.onAccent : AppTheme.textSecondary)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .frame(height: AppTheme.Metrics.chipHeight - AppTheme.Spacing.s)
                .background(isSelected ? AppTheme.accentInk : AppTheme.controlFill, in: .capsule)
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
