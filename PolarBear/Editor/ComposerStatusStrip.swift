//
//  ComposerStatusStrip.swift
//  PolarBear
//

import SwiftUI

/// A slim line above the composer that says what the agent is doing, or that a reply is ready.
/// The conversation itself only opens when the user asks.
struct ComposerStatusStrip: View {
    let agent: AgentModel

    var body: some View {
        HStack(spacing: AppTheme.Spacing.m) {
            if agent.isRunning {
                ProgressView().controlSize(.small)
                Text(agent.activity ?? String(localized: "Working…"))
                    .lineLimit(1)
                Spacer(minLength: 0)
                Button("Stop", action: agent.cancel)
                    .foregroundStyle(AppTheme.link)
            } else if let review = agent.review {
                Image(systemName: "pencil.and.list.clipboard")
                    .accessibilityHidden(true)
                Text("^[\(review.pendingCount) change](inflect: true) proposed")
                    .lineLimit(1)
                Spacer(minLength: 0)
            } else {
                Image(systemName: "text.bubble")
                    .accessibilityHidden(true)
                Text("Reply ready")
                Spacer(minLength: 0)
            }
            Button(agent.review == nil ? "Show" : "Review") { agent.isPanelVisible = true }
                .foregroundStyle(AppTheme.link)
        }
        .buttonStyle(.plain)
        .font(AppTheme.Typography.rowDetail)
        .foregroundStyle(AppTheme.textSecondary)
        .padding(.horizontal, AppTheme.Spacing.xl)
        .frame(height: AppTheme.Metrics.chipHeight)
        .background(AppTheme.controlFill, in: .rect(cornerRadius: AppTheme.Radius.control))
    }
}
