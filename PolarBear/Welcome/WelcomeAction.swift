//
//  WelcomeAction.swift
//  PolarBear
//

import SwiftUI

/// A full-width button of the welcome screen. The prominent one is solid white, like the
/// composer's send button; the others are solid dark with a hairline.
struct WelcomeAction: View {
    let title: LocalizedStringKey
    let systemImage: String
    var isProminent = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
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
        }
        .buttonStyle(.plain)
    }
}
