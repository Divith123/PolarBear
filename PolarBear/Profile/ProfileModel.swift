//
//  ProfileModel.swift
//  PolarBear
//

import SwiftUI
import Observation

/// The app-wide profile. `isSetUp` is false until the first-run screens have been completed.
@Observable
final class ProfileModel {
    private static let storageKey = "userProfile"

    private(set) var profile: UserProfile?
    private(set) var photo: NSImage?

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.storageKey),
           let stored = try? JSONDecoder().decode(UserProfile.self, from: data),
           !stored.name.isEmpty {
            profile = stored
            photo = stored.hasPhoto ? AvatarPhoto.stored() : nil
        }
    }

    var isSetUp: Bool {
        profile != nil
    }

    var name: String {
        profile?.name ?? ""
    }

    /// The profile as an editable draft (empty before the first run).
    var draft: ProfileDraft {
        guard let profile else { return ProfileDraft() }
        return ProfileDraft(name: profile.name, glyph: profile.glyph, colorIndex: profile.colorIndex, photo: photo)
    }

    func save(_ draft: ProfileDraft) {
        guard draft.isValid else { return }
        let stored = UserProfile(
            name: draft.trimmedName,
            glyph: draft.glyph,
            colorIndex: draft.colorIndex,
            hasPhoto: draft.photo != nil
        )
        if let image = draft.photo {
            if image !== photo { AvatarPhoto.store(image) }
        } else {
            AvatarPhoto.removeStored()
        }
        profile = stored
        photo = draft.photo
        if let data = try? JSONEncoder().encode(stored) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }
}
