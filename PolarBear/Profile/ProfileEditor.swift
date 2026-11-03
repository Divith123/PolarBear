//
//  ProfileEditor.swift
//  PolarBear
//

import SwiftUI

/// Name and picture, shared by the first-run screens and Settings.
struct ProfileEditor: View {
    @Binding var draft: ProfileDraft
    var focusesName = false

    @FocusState private var nameFocused: Bool

    private let columns = [GridItem(.adaptive(minimum: AppTheme.Metrics.avatarChoice + AppTheme.Spacing.m), spacing: AppTheme.Spacing.s)]

    var body: some View {
        VStack(spacing: AppTheme.Spacing.xxl) {
            AvatarView(
                name: draft.trimmedName,
                glyph: draft.glyph,
                colorIndex: draft.colorIndex,
                photo: draft.photo,
                size: AppTheme.Metrics.profileAvatar
            )

            TextField("Your name", text: $draft.name)
                .textFieldStyle(.plain)
                .multilineTextAlignment(.center)
                .font(AppTheme.Typography.section)
                .foregroundStyle(AppTheme.textPrimary)
                .padding(.vertical, AppTheme.Spacing.m)
                .padding(.horizontal, AppTheme.Spacing.l)
                .background(AppTheme.controlFill, in: .rect(cornerRadius: AppTheme.Radius.control))
                .overlay {
                    RoundedRectangle(cornerRadius: AppTheme.Radius.control, style: .continuous)
                        .stroke(AppTheme.hairline, lineWidth: 1)
                }
                .focused($nameFocused)
                .onAppear { nameFocused = focusesName }

            LazyVGrid(columns: columns, spacing: AppTheme.Spacing.s) {
                AvatarChoiceButton(title: "Initial", draft: draft, glyph: nil, isSelected: draft.photo == nil && draft.glyph == nil) {
                    draft.photo = nil
                    draft.glyph = nil
                }
                ForEach(AvatarOptions.glyphs, id: \.self) { glyph in
                    AvatarChoiceButton(title: "Symbol", draft: draft, glyph: glyph, isSelected: draft.photo == nil && draft.glyph == glyph) {
                        draft.photo = nil
                        draft.glyph = glyph
                    }
                }
            }

            AvatarColorRow(colorIndex: $draft.colorIndex)

            Button("Choose Photo…", systemImage: "photo", action: choosePhoto)
                .buttonStyle(.link)
                .font(AppTheme.Typography.rowDetail)
        }
    }

    private func choosePhoto() {
        guard let url = FilePanels.chooseImage(message: String(localized: "Choose a picture for your profile.")) else { return }
        Task {
            if let image = await AvatarPhoto.load(from: url) {
                draft.photo = image
            }
        }
    }
}
