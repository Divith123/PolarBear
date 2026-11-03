//
//  ComposerPlusMenu.swift
//  PolarBear
//

import SwiftUI

/// The "+" of the composer: ready-made requests.
struct ComposerPlusMenu: View {
    let agent: AgentModel
    let fix: FixWithAIAction
    let send: (String) -> Void

    var body: some View {
        Menu {
            Button("Review Paper", systemImage: "doc.text.magnifyingglass") {
                send("Review this paper critically. List the main weaknesses in argument, structure and clarity, with concrete suggestions. Do not change any file.")
            }
            Button("Proofread", systemImage: "textformat.abc") {
                send("Proofread the main text for spelling, grammar and typos. Fix only clear mistakes.")
            }
            Button("Fix Build Problems", systemImage: "sparkles", action: fix.perform)
                .disabled(!fix.hasProblems || !fix.isAvailable)
            Divider()
            Button("New Chat", systemImage: "plus.bubble") { agent.newChat() }
        } label: {
            Image(systemName: "plus")
                .foregroundStyle(AppTheme.iconTertiary)
                .frame(width: AppTheme.Metrics.iconButton, height: AppTheme.Metrics.iconButton)
                .contentShape(.rect)
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .accessibilityLabel("Ready-Made Requests")
        .help("Ready-Made Requests")
    }
}
