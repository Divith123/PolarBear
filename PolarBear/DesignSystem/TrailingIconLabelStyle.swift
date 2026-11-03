//
//  TrailingIconLabelStyle.swift
//  PolarBear
//

import SwiftUI

/// A label with its icon after the title, e.g. "Tools ⚠" or "Ninja ⌃⌄".
struct TrailingIconLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: AppTheme.Spacing.s) {
            configuration.title
            configuration.icon
        }
    }
}

extension LabelStyle where Self == TrailingIconLabelStyle {
    static var trailingIcon: TrailingIconLabelStyle { TrailingIconLabelStyle() }
}
