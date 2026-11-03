//
//  EditorEmptyState.swift
//  PolarBear
//

import SwiftUI

/// Shown when every tab is closed: the full original artwork.
struct EditorEmptyState: View {
    var body: some View {
        ContentUnavailableView {
            Label {
                Text("No File Open")
                    .font(AppTheme.Typography.emptyTitle)
            } icon: {
                Image(.polarBearArtwork)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(maxWidth: AppTheme.Metrics.emptyStateArtworkWidth)
                    .clipShape(.rect(cornerRadius: AppTheme.Radius.artwork))
                    .accessibilityHidden(true)
            }
        } description: {
            Text("Pick a file in the sidebar or press ⌘N.")
                .font(AppTheme.Typography.emptyDetail)
        }
        .foregroundStyle(AppTheme.textSecondary)
    }
}

#Preview {
    EditorEmptyState()
        .frame(width: 600, height: 500)
        .background(AppTheme.panelBackground)
}
