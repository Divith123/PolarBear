//
//  IconButton.swift
//  PolarBear
//

import SwiftUI

/// A plain icon-only button. It always has a text title, so VoiceOver and Voice Control can
/// name it; the title is only hidden visually (and shown as a tooltip).
struct IconButton: View {
    let title: LocalizedStringKey
    let systemImage: String
    var tint = AppTheme.iconTertiary
    let action: () -> Void

    var body: some View {
        Button(title, systemImage: systemImage, action: action)
            .labelStyle(.iconOnly)
            .buttonStyle(.plain)
            .foregroundStyle(tint)
            .frame(width: AppTheme.Metrics.iconButton, height: AppTheme.Metrics.iconButton)
            .contentShape(.rect)
            .accessibilityLabel(title)
            .help(title)
    }
}

#Preview {
    IconButton(title: "New File", systemImage: "plus", action: {})
        .padding()
        .background(AppTheme.appBackground)
}
