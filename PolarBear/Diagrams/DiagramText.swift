//
//  DiagramText.swift
//  PolarBear
//

import CoreText
import CoreGraphics
import Foundation

/// Measures and writes the text of diagrams. Widths come from Core Text with the system font, the
/// same font the page uses, so labels fit their boxes.
nonisolated enum DiagramText {
    static let fontSize = 14.0
    static let lineHeight = 19.0

    static func width(_ text: String, size: Double = fontSize, bold: Bool = false, monospaced: Bool = false) -> Double {
        guard !text.isEmpty else { return 0 }
        let font: CTFont
        if monospaced {
            font = CTFontCreateWithName("Menlo" as CFString, size, nil)
        } else if bold {
            font = CTFontCreateUIFontForLanguage(.emphasizedSystem, size, nil) ?? CTFontCreateWithName("Helvetica-Bold" as CFString, size, nil)
        } else {
            font = CTFontCreateUIFontForLanguage(.system, size, nil) ?? CTFontCreateWithName("Helvetica" as CFString, size, nil)
        }
        let attributed = NSAttributedString(string: text, attributes: [NSAttributedString.Key(kCTFontAttributeName as String): font])
        let line = CTLineCreateWithAttributedString(attributed)
        return CTLineGetTypographicBounds(line, nil, nil, nil)
    }

    /// Splits a label into lines at `<br>` and `\n`.
    static func lines(_ label: String) -> [String] {
        label.replacing(/<br\s*\/?>/.ignoresCase(), with: "\n")
            .replacing("\\n", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { String($0).trimmingCharacters(in: .whitespaces) }
    }

    static func size(of lines: [String], fontSize: Double = fontSize, bold: Bool = false) -> (width: Double, height: Double) {
        let width = lines.map { self.width($0, size: fontSize, bold: bold) }.max() ?? 0
        return (width, Double(lines.count) * (fontSize * 1.36))
    }

    /// Text centred on `center`, one `<text>` with a `<tspan>` per line.
    static func centred(_ lines: [String], at center: CGPoint, fontSize: Double = fontSize, bold: Bool = false, fill: String = DiagramTheme.text, anchor: String = "middle") -> String {
        let step = fontSize * 1.36
        let first = center.y - Double(lines.count - 1) * step / 2
        var markup = "<text text-anchor=\"\(anchor)\" font-size=\"\(number(fontSize))\"\(bold ? " font-weight=\"600\"" : "") fill=\"\(fill)\">"
        for (offset, line) in lines.enumerated() {
            markup += "<tspan x=\"\(number(center.x))\" y=\"\(number(first + Double(offset) * step))\" dominant-baseline=\"central\">\(escape(line))</tspan>"
        }
        return markup + "</text>"
    }

    static func escape(_ text: String) -> String {
        MarkdownHTMLWriter.escape(text)
    }

    /// A short decimal for SVG attributes.
    static func number(_ value: Double) -> String {
        let rounded = (value * 100).rounded() / 100
        return rounded == rounded.rounded() ? String(Int(rounded)) : String(rounded)
    }
}
