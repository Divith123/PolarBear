//
//  StaleBanner.swift
//  PolarBear
//

import SwiftUI

/// Shown over the PDF when the latest build failed: the page below is the last good one.
struct StaleBanner: View {
    let errorCount: Int
    let fix: FixWithAIAction?
    let showProblems: () -> Void

    var body: some View {
        HStack(spacing: AppTheme.Spacing.m) {
            Image(systemName: "clock.arrow.circlepath")
                .accessibilityHidden(true)
            Text("Showing the last good PDF. The latest build has ^[\(errorCount) error](inflect: true).")
                .lineLimit(2)
            Spacer(minLength: AppTheme.Spacing.m)
            Button("Show Problems", action: showProblems)
                .buttonStyle(.plain)
                .underline()
            if let fix {
                FixWithAIButton(action: fix)
            }
        }
        .font(AppTheme.Typography.rowDetail)
        .foregroundStyle(AppTheme.warning)
        .padding(.horizontal, AppTheme.Spacing.xl)
        .padding(.vertical, AppTheme.Spacing.m)
        .background(AppTheme.warningFill)
        .overlay(alignment: .bottom) {
            Rectangle().fill(AppTheme.warningStroke).frame(height: 1)
        }
    }
}
