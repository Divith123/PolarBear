//
//  NSColor+Hex.swift
//  PolarBear
//

import SwiftUI

extension NSColor {
    /// An opaque sRGB colour from a 24-bit hex value. Used by the AppKit code editor.
    nonisolated convenience init(hex: UInt32) {
        self.init(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }

    /// A colour that resolves to `light` or `dark` according to the appearance it is drawn in.
    nonisolated convenience init(light: UInt32, dark: UInt32) {
        self.init(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(hex: dark) : NSColor(hex: light)
        }
    }
}
