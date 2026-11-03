//
//  ReviewTray.swift
//  PolarBear
//

import SwiftUI

/// The changes an agent proposed, file by file and hunk by hunk. Nothing reaches the project
/// until a hunk is kept.
struct ReviewTray: View {
    let review: AgentReview
    let agent: AgentModel
    let openFile: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.l) {
            HStack(spacing: AppTheme.Spacing.m) {
                Text("Proposed changes")
                    .font(AppTheme.Typography.rowDetail.bold())
                    .foregroundStyle(AppTheme.textPrimary)
                DiffCounts(added: review.added, removed: review.removed)
                Spacer(minLength: 0)
                Button("Undo All", action: agent.undoAll)
                    .buttonStyle(.plain)
                    .foregroundStyle(AppTheme.textSecondary)
                Button("Keep All", action: agent.keepAll)
                    .buttonStyle(.plain)
                    .foregroundStyle(AppTheme.addedText)
                    .disabled(review.pendingCount == 0)
            }
            .font(AppTheme.Typography.rowDetail)

            ForEach(review.items) { item in
                ReviewItemView(item: item, agent: agent, open: openFile)
            }
        }
        .padding(AppTheme.Spacing.l)
        .background(AppTheme.panelBackground, in: .rect(cornerRadius: AppTheme.Radius.control))
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.Radius.control, style: .continuous)
                .stroke(AppTheme.hairline, lineWidth: 1)
        }
    }
}
