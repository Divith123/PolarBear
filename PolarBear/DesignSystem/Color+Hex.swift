//
//  Color+Hex.swift
//  PolarBear
//

import SwiftUI

extension Color {
    /// An opaque sRGB colour from a 24-bit hex value, e.g. `Color(hex: 0x0D0D0D)`.
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }

    /// A solid colour that is `light` in the light appearance and `dark` in the dark one.
    init(light: UInt32, dark: UInt32) {
        self.init(nsColor: NSColor(light: light, dark: dark))
    }
}
