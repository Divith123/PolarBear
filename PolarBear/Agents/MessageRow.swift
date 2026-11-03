//
//  MessageRow.swift
//  PolarBear
//

import SwiftUI

struct MessageRow: View {
    let message: ChatMessage

    var body: some View {
        switch message.role {
        case .user:
            Text(message.text)
                .font(AppTheme.Typography.rowDetail)
                .foregroundStyle(AppTheme.textPrimary)
                .textSelection(.enabled)
                .padding(.horizontal, AppTheme.Spacing.l)
                .padding(.vertical, AppTheme.Spacing.m)
                .background(AppTheme.controlFill, in: .rect(cornerRadius: AppTheme.Radius.control))
                .frame(maxWidth: .infinity, alignment: .trailing)
        case .assistant:
            Text(message.text)
                .font(AppTheme.Typography.rowDetail)
                .foregroundStyle(AppTheme.textPrimary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        case .activity:
            Label(message.text, systemImage: "circle.fill")
                .labelStyle(.titleAndIcon)
                .imageScale(.small)
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.textTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
        case .error:
            Label(message.text, systemImage: "exclamationmark.triangle")
                .font(AppTheme.Typography.rowDetail)
                .foregroundStyle(AppTheme.danger)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
