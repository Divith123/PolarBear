//
//  AppearanceSetting.swift
//  PolarBear
//

import SwiftUI

/// The theme the user chose: always dark (the default), always light, or the system's.
enum AppearanceSetting: String, CaseIterable, Identifiable {
    case dark
    case light
    case system

    static let storageKey = "appearance"

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .dark: "Dark"
        case .light: "Light"
        case .system: "Match System"
        }
    }

    var symbol: String {
        switch self {
        case .dark: "moon"
        case .light: "sun.max"
        case .system: "circle.lefthalf.filled"
        }
    }

    /// `nil` follows the system.
    var colorScheme: ColorScheme? {
        switch self {
        case .dark: .dark
        case .light: .light
        case .system: nil
        }
    }
}
