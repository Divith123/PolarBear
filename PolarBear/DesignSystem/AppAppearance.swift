//
//  AppAppearance.swift
//  PolarBear
//

import SwiftUI

/// Applies the chosen theme to a window, sheet or popover. Every presentation uses it, so
/// changing the setting restyles everything that is open.
struct AppAppearance: ViewModifier {
    @AppStorage(AppearanceSetting.storageKey) private var setting = AppearanceSetting.dark

    func body(content: Content) -> some View {
        content.preferredColorScheme(setting.colorScheme)
    }
}

extension View {
    func appAppearance() -> some View {
        modifier(AppAppearance())
    }
}
