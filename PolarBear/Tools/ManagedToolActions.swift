//
//  ManagedToolActions.swift
//  PolarBear
//

import SwiftUI

/// What the settings offer for a tool that PolarBear can install: install it when it is missing;
/// when PolarBear installed it, say so and offer to remove it (and, for OpenCode, to sign in).
struct ManagedToolActions: View {
    @Environment(ProjectLibrary.self) private var library
    let tool: ManagedTool
    let url: URL?

    var body: some View {
        if let url {
            HStack(spacing: AppTheme.Spacing.m) {
                if tool == .openCode {
                    Button("Sign In…") { OpenCodeSignIn.open(executable: url) }
                        .help("Opens Terminal to connect OpenCode to an AI provider. Some models are free and need no sign-in.")
                }
                if ToolStore.isManaged(url) {
                    Text("Installed by PolarBear")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(.secondary)
                    Button("Remove") { library.uninstall(tool) }
                        .buttonStyle(.link)
                }
            }
        } else {
            ToolInstallControl(tool: tool)
        }
    }
}
