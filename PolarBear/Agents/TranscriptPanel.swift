//
//  TranscriptPanel.swift
//  PolarBear
//

import SwiftUI

/// The conversation with the agent, opened above the composer: what was asked, what the agent
/// said and did, and — when it changed files — the changes waiting for review.
struct TranscriptPanel: View {
    let agent: AgentModel
    let workspace: WorkspaceModel

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            TranscriptHeader(
                title: agent.currentSession?.title ?? String(localized: "New Chat"),
                agentName: agent.currentSession?.agent.displayName,
                newChat: agent.newChat,
                close: { agent.isPanelVisible = false }
            )

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: AppTheme.Spacing.m) {
                        ForEach(agent.currentSession?.messages ?? []) { message in
                            MessageRow(message: message)
                        }
                        if agent.isRunning {
                            RunningRow(activity: agent.activity, stop: agent.cancel)
                        }
                        if let review = agent.review {
                            ReviewTray(review: review, agent: agent, openFile: { workspace.open(path: $0, line: nil) })
                        }
                        Color.clear.frame(height: 1).id("end")
                    }
                    .padding(AppTheme.Spacing.xl)
                }
                .scrollIndicators(.hidden)
                .onChange(of: agent.currentSession?.messages.count) { scrollToEnd(proxy) }
                .onChange(of: agent.review?.pendingCount) { scrollToEnd(proxy) }
                .onChange(of: agent.activity) { scrollToEnd(proxy) }
            }
        }
        .frame(maxHeight: 400)
        .background(AppTheme.composerFill, in: .rect(cornerRadius: AppTheme.Radius.pill))
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.Radius.pill, style: .continuous)
                .stroke(AppTheme.hairline, lineWidth: 1)
        }
    }

    private func scrollToEnd(_ proxy: ScrollViewProxy) {
        withAnimation(reduceMotion ? nil : AppTheme.Timing.scroll) {
            proxy.scrollTo("end", anchor: .bottom)
        }
    }
}
