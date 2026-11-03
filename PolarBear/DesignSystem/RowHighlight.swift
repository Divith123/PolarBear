//
//  RowHighlight.swift
//  PolarBear
//

import SwiftUI

/// Solid selection / hover background for list-like rows. Keeping the hover state here
/// means each row only depends on the values it is given.
struct RowHighlight: ViewModifier {
    let isSelected: Bool
    let cornerRadius: Double

    @State private var isHovering = false

    func body(content: Content) -> some View {
        content
            .background(fill, in: .rect(cornerRadius: cornerRadius))
            .contentShape(.rect(cornerRadius: cornerRadius))
            .onHover { isHovering = $0 }
    }

    private var fill: Color {
        if isSelected {
            AppTheme.selectionFill
        } else if isHovering {
            AppTheme.hoverFill
        } else {
            .clear
        }
    }
}

extension View {
    func rowHighlight(isSelected: Bool, cornerRadius: Double = AppTheme.Radius.row) -> some View {
        modifier(RowHighlight(isSelected: isSelected, cornerRadius: cornerRadius))
    }
}
