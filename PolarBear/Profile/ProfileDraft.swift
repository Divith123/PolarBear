//
//  ProfileDraft.swift
//  PolarBear
//

import SwiftUI

/// The profile while it is being edited, before it is saved.
struct ProfileDraft: Equatable {
    var name = ""
    var glyph: String?
    var colorIndex = 3
    var photo: NSImage?

    var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isValid: Bool {
        !trimmedName.isEmpty
    }
}
