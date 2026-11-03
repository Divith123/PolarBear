//
//  AgentOptions.swift
//  PolarBear
//

import Foundation

/// The model and reasoning effort the user chose for an agent. `nil` leaves the choice to the CLI.
nonisolated struct AgentOptions: Codable, Equatable, Sendable {
    var model: String?
    var effort: String?

    /// Model ids and effort names are passed to a program as arguments, so only plain
    /// identifier characters are accepted, and never a leading dash (which would read as a flag).
    static func sanitised(_ raw: String?) -> String? {
        guard let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty,
              !trimmed.hasPrefix("-"), trimmed.count <= 120 else { return nil }
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789._:/#@+-[]")
        return trimmed.unicodeScalars.allSatisfy(allowed.contains) ? trimmed : nil
    }
}
