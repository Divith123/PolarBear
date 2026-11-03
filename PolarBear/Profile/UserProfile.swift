//
//  UserProfile.swift
//  PolarBear
//

import Foundation

/// Who is using PolarBear: a name and a picture. It stays on this Mac and is only shown in the
/// sidebar; nothing is sent anywhere.
nonisolated struct UserProfile: Codable, Equatable, Sendable {
    var name: String
    /// An SF Symbol drawn on the avatar; `nil` shows the name's initial.
    var glyph: String?
    /// Index into `AppTheme.avatarColors`.
    var colorIndex: Int
    /// A photo chosen by the user is stored next to the app's other data.
    var hasPhoto: Bool
}
