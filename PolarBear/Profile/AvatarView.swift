//
//  AvatarView.swift
//  PolarBear
//

import SwiftUI

/// A round profile picture: the photo, or a symbol, or the name's initial on a solid colour.
struct AvatarView: View {
    let name: String
    var glyph: String?
    var colorIndex = 3
    var photo: NSImage?
    var size = AppTheme.Metrics.accountAvatar

    var body: some View {
        Group {
            if let photo {
                Image(nsImage: photo)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFill()
            } else {
                ZStack {
                    AppTheme.avatarColors[colorIndex % AppTheme.avatarColors.count]
                    if let glyph {
                        Image(systemName: glyph)
                            .resizable()
                            .scaledToFit()
                            .fontWeight(.semibold)
                            .frame(width: size * 0.44, height: size * 0.44)
                    } else {
                        // The initial shrinks to fit the circle instead of using a fixed point size.
                        Text(name.prefix(1).uppercased())
                            .font(.largeTitle.weight(.semibold))
                            .minimumScaleFactor(0.1)
                            .lineLimit(1)
                            .frame(width: size * 0.5, height: size * 0.5)
                    }
                }
                .foregroundStyle(AppTheme.onAvatarColor)
            }
        }
        .frame(width: size, height: size)
        .clipShape(.circle)
        .accessibilityHidden(true)
    }
}
