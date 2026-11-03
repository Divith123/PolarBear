//
//  AppearancePicker.swift
//  PolarBear
//

import SwiftUI

/// Choose Dark, Light or Match System. Used in Settings and in the sidebar's bottom menu.
struct AppearancePicker: View {
    @AppStorage(AppearanceSetting.storageKey) private var setting = AppearanceSetting.dark

    var body: some View {
        Picker("Appearance", selection: $setting) {
            ForEach(AppearanceSetting.allCases) { option in
                Label(option.title, systemImage: option.symbol).tag(option)
            }
        }
    }
}
