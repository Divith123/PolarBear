//
//  OutlineHeader.swift
//  PolarBear
//

import SwiftUI

struct OutlineHeader: View {
    let isExpanded: Bool
    let toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            Label {
                Text("Outline")
                    .font(AppTheme.Typography.section)
                    .foregroundStyle(AppTheme.textPrimary)
            } icon: {
                Image(systemName: "chevron.down")
                    .imageScale(.small)
                    .foregroundStyle(AppTheme.iconPrimary)
                    .rotationEffect(.degrees(isExpanded ? 0 : -90))
            }
            .padding(.leading, AppTheme.Spacing.xs)
            .frame(maxWidth: .infinity, minHeight: AppTheme.Metrics.outlineHeaderHeight, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
    }
}
