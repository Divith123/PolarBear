//
//  ChatRow.swift
//  PolarBear
//

import SwiftUI

struct ChatRow: View {
    let session: ChatSession
    let isActive: Bool
    let select: (ChatSession) -> Void
    let delete: (ChatSession) -> Void

    var body: some View {
        Button {
            select(session)
        } label: {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                Text(session.title)
                    .font(AppTheme.Typography.row)
                    .foregroundStyle(isActive ? AppTheme.iconPrimary : AppTheme.textSecondary)
                    .lineLimit(1)
                HStack(spacing: AppTheme.Spacing.s) {
                    Text(session.agent.displayName)
                    Text(session.created, format: .relative(presentation: .named))
                }
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.textTertiary)
            }
            .padding(.horizontal, AppTheme.Spacing.l)
            .padding(.vertical, AppTheme.Spacing.s)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .rowHighlight(isSelected: isActive)
        .contextMenu {
            Button("Delete Chat", role: .destructive) { delete(session) }
        }
    }
}
