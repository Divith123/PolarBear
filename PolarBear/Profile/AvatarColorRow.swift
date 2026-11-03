//
//  AvatarColorRow.swift
//  PolarBear
//

import SwiftUI

/// The colour choices of the profile picture.
struct AvatarColorRow: View {
    @Binding var colorIndex: Int

    var body: some View {
        HStack(spacing: AppTheme.Spacing.l) {
            ForEach(AppTheme.avatarColors.indices, id: \.self) { index in
                Button("Colour \(index + 1)") {
                    colorIndex = index
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.plain)
                .frame(width: AppTheme.Metrics.avatarSwatch, height: AppTheme.Metrics.avatarSwatch)
                .background(AppTheme.avatarColors[index], in: .circle)
                .overlay {
                    Circle()
                        .stroke(AppTheme.textPrimary, lineWidth: colorIndex == index ? 2 : 0)
                        .padding(-AppTheme.Spacing.xs)
                }
                .accessibilityAddTraits(colorIndex == index ? .isSelected : [])
            }
        }
    }
}
