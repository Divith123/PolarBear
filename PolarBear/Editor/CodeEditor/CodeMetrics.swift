//
//  CodeMetrics.swift
//  PolarBear
//

import SwiftUI

/// Measurements of the AppKit code editor. They are `CGFloat` because AppKit requires it.
enum CodeMetrics {
    static let font = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)

    /// Advance of one column; used for the hanging indent of wrapped lines.
    static let characterWidth: CGFloat = ("0" as NSString).size(withAttributes: [.font: font]).width

    /// Extra space below each text row, so rows have a calm 1.25× rhythm.
    static let lineSpacing: CGFloat = NSLayoutManager().defaultLineHeight(for: font) * 0.25

    /// Left margin that holds the line numbers.
    static let gutterWidth: CGFloat = 62
    /// Line numbers are right-aligned to this x position.
    static let numberTrailingEdge: CGFloat = 41
    static let trailingPadding: CGFloat = 27
    static let topInset: CGFloat = 8
    /// Lets the last lines scroll clear of the composer.
    static let bottomInset: CGFloat = 24
}
