//
//  FixWithAIButton.swift
//  PolarBear
//

import SwiftUI

/// "Fix with AI": sends the build's errors and warnings to the assistant in the open conversation.
struct FixWithAIButton: View {
    let action: FixWithAIAction

    var body: some View {
        Button(action: action.perform) {
            Label("Fix with AI", systemImage: "sparkles")
                .font(AppTheme.Typography.rowDetail.weight(.semibold))
                .foregroundStyle(AppTheme.onAccent)
                .padding(.horizontal, AppTheme.Spacing.l)
                .frame(height: AppTheme.Metrics.controlHeight - AppTheme.Spacing.xs)
                .background(AppTheme.accentInk, in: .capsule)
                .opacity(action.isAvailable ? 1 : 0.45)
        }
        .buttonStyle(.plain)
        .disabled(!action.isAvailable)
        .help(action.unavailableReason ?? String(localized: "Send the errors and warnings to the assistant and ask it to fix them"))
    }
}
