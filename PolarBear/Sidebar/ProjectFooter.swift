//
//  ProjectFooter.swift
//  PolarBear
//

import SwiftUI

/// Pinned to the bottom of the sidebar: where the project lives, with a menu for the settings.
struct ProjectFooter: View {
    @Environment(WorkspaceModel.self) private var workspace
    @Environment(WindowState.self) private var window
    @Environment(ProjectLibrary.self) private var library

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle()
                .fill(AppTheme.divider)
                .frame(height: 1)

            Menu {
                SettingsLink {
                    Label("Settings…", systemImage: "gearshape")
                }
                AppearancePicker()
                Button("Show in Finder") { workspace.revealProjectInFinder() }
                Divider()
                Button("Close Project") { window.closeProject() }
            } label: {
                HStack(spacing: AppTheme.Spacing.l) {
                    AvatarView(
                        name: displayName,
                        glyph: library.profile.profile?.glyph,
                        colorIndex: library.profile.profile?.colorIndex ?? 3,
                        photo: library.profile.photo
                    )

                    VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                        Label {
                            Text(displayName)
                                .font(AppTheme.Typography.row.bold())
                                .foregroundStyle(AppTheme.textPrimary)
                                .lineLimit(1)
                        } icon: {
                            Image(systemName: "chevron.up.chevron.down")
                                .imageScale(.small)
                                .foregroundStyle(AppTheme.textTertiary)
                        }
                        .labelStyle(.trailingIcon)

                        Label {
                            Text(folderPath)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        } icon: {
                            Image(systemName: "folder")
                        }
                        .font(AppTheme.Typography.rowDetail)
                        .foregroundStyle(AppTheme.textTertiary)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, AppTheme.Spacing.xxl)
                .padding(.vertical, AppTheme.Spacing.xl)
                .contentShape(.rect)
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .accessibilityLabel("Account: \(displayName)")
        }
    }

    /// The user's name; the project's, only if no profile exists.
    private var displayName: String {
        library.profile.isSetUp ? library.profile.name : workspace.project.name
    }

    private var folderPath: String {
        let parent = workspace.project.root.deletingLastPathComponent().path(percentEncoded: false)
        let home = FileManager.default.homeDirectoryForCurrentUser.path(percentEncoded: false)
        return parent.hasPrefix(home) ? "~" + parent.dropFirst(home.count) : parent
    }
}
