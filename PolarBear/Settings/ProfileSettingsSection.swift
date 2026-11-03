//
//  ProfileSettingsSection.swift
//  PolarBear
//

import SwiftUI

/// Edit the name and picture shown at the bottom of the sidebar. Changes apply as you make them.
struct ProfileSettingsSection: View {
    @Environment(ProjectLibrary.self) private var library
    @State private var draft = ProfileDraft()

    var body: some View {
        ProfileEditor(draft: $draft)
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppTheme.Spacing.m)
            .onAppear { draft = library.profile.draft }
            .onChange(of: draft) { _, edited in
                library.profile.save(edited)
            }
    }
}
