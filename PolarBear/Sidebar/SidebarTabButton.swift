//
//  SidebarTabButton.swift
//  PolarBear
//

import SwiftUI

struct SidebarTabButton: View {
    let tab: SidebarTab
    let isSelected: Bool
    let select: (SidebarTab) -> Void

    var body: some View {
        Button {
            select(tab)
        } label: {
            Text(tab.title)
                .font(AppTheme.Typography.row)
                .foregroundStyle(isSelected ? AppTheme.textPrimary : AppTheme.textSecondary)
                .frame(maxHeight: .infinity)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(AppTheme.accentInk)
                        .frame(height: 2)
                        .opacity(isSelected ? 1 : 0)
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
