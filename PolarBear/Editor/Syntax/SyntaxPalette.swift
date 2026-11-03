//
//  SyntaxPalette.swift
//  PolarBear
//

import SwiftUI

/// Colours of the code editor. They are `NSColor`s because the editor is AppKit; each one
/// follows the window's light or dark appearance.
enum SyntaxPalette {
    static let text = NSColor(light: 0x1C1C1E, dark: 0xEDEDED)
    static let comment = NSColor(light: 0x6A737D, dark: 0x8A8A8A)
    static let bracket = NSColor(light: 0x946400, dark: 0xE2C275)
    static let math = NSColor(light: 0x7B3FB8, dark: 0xC586EA)
    static let argument = NSColor(light: 0x1F5FBF, dark: 0x9DBDF5)
    static let heading = NSColor(light: 0xB3261E, dark: 0xFF9E8F)
    static let code = NSColor(light: 0x1B7A43, dark: 0x8FD9A8)
    static let link = NSColor(light: 0x1F5FBF, dark: 0x7FB0F5)
    static let quote = NSColor(light: 0x6A737D, dark: 0x9A9A9A)
    static let marker = NSColor(light: 0x946400, dark: 0xE2C275)
    static let emphasis = NSColor(light: 0x7B3FB8, dark: 0xC586EA)

    static let selection = NSColor(light: 0xBBD6FB, dark: 0x2B3F5C)
    static let caret = NSColor(light: 0x000000, dark: 0xFFFFFF)
    static let lineNumber = NSColor(light: 0x9A9AA4, dark: 0x7A7A7A)
    static let activeLineNumber = NSColor(light: 0x3A3A40, dark: 0xD0D0D0)
    static let activeLineBorder = NSColor(light: 0xC9C9D0, dark: 0x484848)

    static let errorMarker = NSColor(light: 0xC62828, dark: 0xFF7A7A)
    static let warningMarker = NSColor(light: 0x946400, dark: 0xE5C07B)

    static func color(for kind: LaTeXTokenKind) -> NSColor {
        switch kind {
        case .text: text
        case .comment: comment
        case .bracket: bracket
        case .math: math
        case .argument: argument
        case .heading: heading
        case .code: code
        case .link: link
        case .quote: quote
        case .marker: marker
        case .emphasis: emphasis
        }
    }
}
