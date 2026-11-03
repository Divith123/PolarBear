//
//  OnboardingButton.swift
//  PolarBear
//

import SwiftUI

/// A full-width solid button of the first-run screens.
struct OnboardingButton: View {
    let title: LocalizedStringKey
    let isProminent: Bool
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(AppTheme.Typography.row)
                .foregroundStyle(isProminent ? AppTheme.onAccent : AppTheme.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: AppTheme.Metrics.controlHeight + AppTheme.Spacing.s)
                .background(isProminent ? AppTheme.accentInk : AppTheme.controlFill, in: .rect(cornerRadius: AppTheme.Radius.control))
                .overlay {
                    RoundedRectangle(cornerRadius: AppTheme.Radius.control, style: .continuous)
                        .stroke(isProminent ? Color.clear : AppTheme.hairline, lineWidth: 1)
                }
                .contentShape(.rect(cornerRadius: AppTheme.Radius.control))
                .opacity(isEnabled ? 1 : 0.4)
        }
        .buttonStyle(.plain)
    }
}
