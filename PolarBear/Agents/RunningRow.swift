//
//  RunningRow.swift
//  PolarBear
//

import SwiftUI

/// "Editing main.tex…" with a Stop button, while an agent runs.
struct RunningRow: View {
    let activity: String?
    let stop: () -> Void

    var body: some View {
        HStack(spacing: AppTheme.Spacing.m) {
            ProgressView().controlSize(.small)
            Text(activity ?? String(localized: "Working…"))
                .font(AppTheme.Typography.rowDetail)
                .foregroundStyle(AppTheme.textSecondary)
                .lineLimit(1)
            Spacer(minLength: 0)
            Button("Stop", action: stop)
                .buttonStyle(.plain)
                .font(AppTheme.Typography.rowDetail)
                .foregroundStyle(AppTheme.link)
        }
    }
}
