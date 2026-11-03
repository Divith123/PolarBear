//
//  DrawerTabBar.swift
//  PolarBear
//

import SwiftUI

struct DrawerTabBar: View {
    let tab: DrawerTab
    let errorCount: Int
    let select: (DrawerTab) -> Void
    let close: () -> Void

    var body: some View {
        HStack(spacing: AppTheme.Spacing.l) {
            ForEach(DrawerTab.allCases) { candidate in
                Button {
                    select(candidate)
                } label: {
                    HStack(spacing: AppTheme.Spacing.xs) {
                        Text(candidate.title)
                            .font(AppTheme.Typography.rowDetail)
                            .foregroundStyle(candidate == tab ? AppTheme.textPrimary : AppTheme.textSecondary)
                            .lineLimit(1)
                        if candidate == .problems, errorCount > 0 {
                            Text("\(errorCount)")
                                .font(AppTheme.Typography.badge)
                                .foregroundStyle(AppTheme.danger)
                        }
                    }
                    .frame(maxHeight: .infinity)
                    .overlay(alignment: .bottom) {
                        Rectangle()
                            .fill(AppTheme.accentInk)
                            .frame(height: 2)
                            .opacity(candidate == tab ? 1 : 0)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(candidate == tab ? .isSelected : [])
            }

            Spacer(minLength: 0)

            IconButton(title: "Close Drawer", systemImage: "xmark", action: close)
        }
        .padding(.horizontal, AppTheme.Spacing.xl)
        .frame(height: AppTheme.Metrics.barHeight)
        .overlay(alignment: .bottom) {
            Rectangle().fill(AppTheme.hairlineFaint).frame(height: 1)
        }
    }
}
