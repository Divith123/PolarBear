//
//  BetaBadge.swift
//  PolarBear
//

import SwiftUI

struct BetaBadge: View {
    var body: some View {
        Text("BETA", comment: "Badge next to the logo marking the app as a beta version.")
            .font(AppTheme.Typography.badge)
            .foregroundStyle(AppTheme.textSecondary)
            .padding(.horizontal, AppTheme.Spacing.s)
            .padding(.vertical, AppTheme.Spacing.xxs)
            .background(AppTheme.badgeFill, in: .rect(cornerRadius: AppTheme.Radius.badge))
    }
}
