//
//  TabStripFade.swift
//  PolarBear
//

import SwiftUI

/// Mask that softens both ends of the tab strip while it scrolls; fully opaque otherwise.
struct TabStripFade: View {
    let isOverflowing: Bool

    private let fadeWidth = AppTheme.Spacing.xl

    var body: some View {
        HStack(spacing: 0) {
            LinearGradient(colors: [.clear, .black], startPoint: .leading, endPoint: .trailing)
                .frame(width: isOverflowing ? fadeWidth : 0)
            Rectangle()
            LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing)
                .frame(width: isOverflowing ? fadeWidth : 0)
        }
    }
}
