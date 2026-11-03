//
//  OutlinePane.swift
//  PolarBear
//

import SwiftUI

/// The collapsible outline of the active document. Its height follows the window.
struct OutlinePane: View {
    @Environment(WorkspaceModel.self) private var workspace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isExpanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            OutlineHeader(isExpanded: isExpanded, toggle: toggle)

            if isExpanded {
                OutlineList(items: workspace.outline, reveal: workspace.reveal)
            }
        }
        .padding(.horizontal, AppTheme.Spacing.xl)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .containerRelativeFrame(.vertical, alignment: .top) { [isExpanded] length, _ in
            CGFloat(Self.height(forWindowHeight: Double(length), isExpanded: isExpanded))
        }
        .clipped()
    }

    private func toggle() {
        withAnimation(reduceMotion ? nil : AppTheme.Timing.disclosure) {
            isExpanded.toggle()
        }
    }

    private static func height(forWindowHeight windowHeight: Double, isExpanded: Bool) -> Double {
        guard isExpanded else { return AppTheme.Metrics.collapsedOutlineHeight }
        let proportional = windowHeight * 0.3
        return min(max(proportional, AppTheme.Metrics.outlineMinHeight), AppTheme.Metrics.outlineMaxHeight)
    }
}
