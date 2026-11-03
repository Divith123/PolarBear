//
//  TranscriptHeader.swift
//  PolarBear
//

import SwiftUI

struct TranscriptHeader: View {
    let title: String
    let agentName: String?
    let newChat: () -> Void
    let close: () -> Void

    var body: some View {
        HStack(spacing: AppTheme.Spacing.m) {
            Image(systemName: "sparkles")
                .foregroundStyle(AppTheme.iconSecondary)
                .accessibilityHidden(true)
            Text(title)
                .font(AppTheme.Typography.rowDetail.bold())
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(1)
            if let agentName {
                Text(agentName)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.textTertiary)
            }
            Spacer(minLength: 0)
            IconButton(title: "New Chat", systemImage: "square.and.pencil", action: newChat)
            IconButton(title: "Close Conversation", systemImage: "chevron.down", action: close)
        }
        .padding(.horizontal, AppTheme.Spacing.xl)
        .frame(height: AppTheme.Metrics.drawerRowHeight)
        .overlay(alignment: .bottom) {
            Rectangle().fill(AppTheme.hairlineFaint).frame(height: 1)
        }
    }
}
