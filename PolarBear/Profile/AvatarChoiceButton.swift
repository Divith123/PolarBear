//
//  AvatarChoiceButton.swift
//  PolarBear
//

import SwiftUI

/// One selectable picture in the profile editor: the initial, a symbol, or the chosen photo.
struct AvatarChoiceButton: View {
    let title: LocalizedStringKey
    let draft: ProfileDraft
    /// The symbol this button stands for; `nil` is the initial.
    let glyph: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            AvatarView(name: draft.trimmedName, glyph: glyph, colorIndex: draft.colorIndex, size: AppTheme.Metrics.avatarChoice)
                .overlay {
                    Circle()
                        .stroke(isSelected ? AppTheme.textPrimary : AppTheme.hairline, lineWidth: isSelected ? 2 : 1)
                }
                .padding(AppTheme.Spacing.xxs)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .help(title)
    }
}
