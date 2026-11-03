//
//  ReviewItemView.swift
//  PolarBear
//

import SwiftUI

/// One file of a proposal: its name, and a card for every hunk still waiting for a decision.
struct ReviewItemView: View {
    let item: ReviewItem
    let agent: AgentModel
    let open: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.m) {
            HStack(spacing: AppTheme.Spacing.m) {
                Button {
                    open(item.change.path)
                } label: {
                    Text(item.change.path)
                        .font(AppTheme.Typography.rowDetail.bold())
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineLimit(1)
                        .truncationMode(.head)
                }
                .buttonStyle(.plain)
                .disabled(item.change.status == .deleted)

                Text(statusText)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.textTertiary)
                Spacer(minLength: 0)
                DiffCounts(added: item.change.added, removed: item.change.removed)
            }

            if item.isStale {
                Label("Changed since the agent started. Ask again to review it.", systemImage: "exclamationmark.triangle")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.warning)
            } else if item.pendingHunks.isEmpty {
                Label("\(item.keptHunks.count) kept, \(item.undoneHunks.count) undone", systemImage: "checkmark")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.textTertiary)
            } else {
                ForEach(item.pendingHunks) { hunk in
                    HunkCard(
                        hunk: hunk,
                        keep: { agent.keep(hunk, in: item.change.path) },
                        undo: { agent.undo(hunk, in: item.change.path) }
                    )
                }
            }
        }
    }

    private var statusText: LocalizedStringKey {
        switch item.change.status {
        case .added: "new file"
        case .modified: "edited"
        case .deleted: "deleted"
        }
    }
}
