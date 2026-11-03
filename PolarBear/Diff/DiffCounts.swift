//
//  DiffCounts.swift
//  PolarBear
//

import SwiftUI

/// "+12 −3" in green and red.
struct DiffCounts: View {
    let added: Int
    let removed: Int

    var body: some View {
        HStack(spacing: AppTheme.Spacing.s) {
            Text("+\(added)")
                .foregroundStyle(added == 0 ? AppTheme.textTertiary : AppTheme.addedText)
            Text("−\(removed)")
                .foregroundStyle(removed == 0 ? AppTheme.textTertiary : AppTheme.removedText)
        }
        .font(AppTheme.Typography.codeSmall)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(added) lines added, \(removed) removed")
    }
}
