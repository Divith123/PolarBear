//
//  MarkdownLines.swift
//  PolarBear
//

import Foundation

/// The small line-level tests the block parser is built from.
nonisolated enum MarkdownLines {
    static func isBlank(_ line: String) -> Bool {
        line.allSatisfy { $0 == " " || $0 == "\t" }
    }

    static func indent(of line: String) -> Int {
        line.prefix(while: { $0 == " " }).count
    }

    static func trimmingLeadingSpaces(_ line: String) -> String {
        String(line.drop(while: { $0 == " " }))
    }

    /// Tabs become spaces (to the next multiple of four) so indentation can be counted.
    static func expandTabs(_ line: String) -> String {
        guard line.contains("\t") else { return line }
        var result = ""
        var column = 0
        for character in line {
            if character == "\t" {
                let width = 4 - column % 4
                result += String(repeating: " ", count: width)
                column += width
            } else {
                result.append(character)
                column += 1
            }
        }
        return result
    }

    // MARK: Headings and rules

    /// `# Title` → (1, "Title").
    static func atxHeading(_ line: String) -> (level: Int, text: String)? {
        guard indent(of: line) <= 3 else { return nil }
        let body = trimmingLeadingSpaces(line)
        let hashes = body.prefix(while: { $0 == "#" }).count
        guard (1...6).contains(hashes) else { return nil }
        let rest = body.dropFirst(hashes)
        guard rest.isEmpty || rest.first == " " else { return nil }
        var text = rest.trimmingCharacters(in: .whitespaces)
        // An optional closing sequence of #s.
        if let closing = text.lastIndex(where: { $0 != "#" }) {
            let tail = text[text.index(after: closing)...]
            if !tail.isEmpty, text[closing] == " " { text = String(text[...closing]).trimmingCharacters(in: .whitespaces) }
        } else {
            text = ""
        }
        return (hashes, text)
    }

    static func isThematicBreak(_ line: String) -> Bool {
        guard indent(of: line) <= 3 else { return false }
        let body = line.filter { $0 != " " }
        guard body.count >= 3, let first = body.first, "-*_".contains(first) else { return false }
        return body.allSatisfy { $0 == first }
    }

    /// `===` (level 1) or `---` (level 2) under a paragraph.
    static func setextLevel(_ line: String) -> Int? {
        guard indent(of: line) <= 3 else { return nil }
        let body = line.trimmingCharacters(in: .whitespaces)
        guard let first = body.first, body.allSatisfy({ $0 == first }) else { return nil }
        if first == "=" { return 1 }
        if first == "-" { return 2 }
        return nil
    }

    // MARK: Fences

    struct Fence {
        var character: Character
        var length: Int
        var indent: Int
        var info: String
    }

    static func fenceStart(_ line: String) -> Fence? {
        let spaces = indent(of: line)
        guard spaces <= 3 else { return nil }
        let body = line.dropFirst(spaces)
        guard let first = body.first, first == "`" || first == "~" else { return nil }
        let length = body.prefix(while: { $0 == first }).count
        guard length >= 3 else { return nil }
        let info = body.dropFirst(length).trimmingCharacters(in: .whitespaces)
        if first == "`", info.contains("`") { return nil }
        return Fence(character: first, length: length, indent: spaces, info: info)
    }

    static func closes(_ line: String, fence: Fence) -> Bool {
        let spaces = indent(of: line)
        guard spaces <= 3 else { return false }
        let body = line.dropFirst(spaces)
        let run = body.prefix(while: { $0 == fence.character }).count
        return run >= fence.length && body.dropFirst(run).allSatisfy { $0 == " " }
    }

    // MARK: Quotes, lists, HTML

    static func isQuote(_ line: String) -> Bool {
        indent(of: line) <= 3 && trimmingLeadingSpaces(line).hasPrefix(">")
    }

    static func strippingQuoteMarker(_ line: String) -> String {
        var body = trimmingLeadingSpaces(line)
        body.removeFirst()
        if body.first == " " { body.removeFirst() }
        return body
    }

    struct ListMarker {
        var indent: Int
        /// Columns the marker and the spaces after it take: where the item's content starts.
        var contentColumn: Int
        var start: Int?
        var character: Character
        var content: String
    }

    static func listMarker(_ line: String) -> ListMarker? {
        let spaces = indent(of: line)
        guard spaces <= 3 else { return nil }
        let body = Array(line.dropFirst(spaces))
        guard let first = body.first else { return nil }

        var markerLength = 0
        var start: Int?
        var character = first
        if "-+*".contains(first) {
            markerLength = 1
        } else if first.isASCII, first.isNumber {
            let digits = body.prefix(while: { $0.isASCII && $0.isNumber })
            guard digits.count <= 9, digits.count < body.count else { return nil }
            let delimiter = body[digits.count]
            guard delimiter == "." || delimiter == ")" else { return nil }
            markerLength = digits.count + 1
            start = Int(String(digits))
            character = delimiter
        } else {
            return nil
        }

        let after = body.dropFirst(markerLength)
        if after.isEmpty {
            return ListMarker(indent: spaces, contentColumn: spaces + markerLength + 1, start: start, character: character, content: "")
        }
        guard after.first == " " else { return nil }
        let gap = after.prefix(while: { $0 == " " }).count
        let usedGap = gap > 4 ? 1 : gap
        let content = String(after.dropFirst(usedGap))
        return ListMarker(indent: spaces, contentColumn: spaces + markerLength + usedGap, start: start, character: character, content: content)
    }

    private static let htmlBlockTags: Set<String> = [
        "address", "article", "aside", "blockquote", "body", "center", "details", "dialog", "dd", "div", "dl", "dt",
        "fieldset", "figcaption", "figure", "footer", "form", "h1", "h2", "h3", "h4", "h5", "h6", "header", "hr",
        "html", "li", "main", "nav", "ol", "p", "picture", "pre", "section", "summary", "table", "tbody", "td",
        "tfoot", "th", "thead", "tr", "ul", "video", "iframe", "script", "style",
    ]

    /// A line that opens a block of raw HTML (`<div>`, `<!-- … -->`).
    static func isHTMLBlockStart(_ line: String) -> Bool {
        guard indent(of: line) <= 3 else { return false }
        let body = trimmingLeadingSpaces(line)
        guard body.hasPrefix("<") else { return false }
        if body.hasPrefix("<!--") { return true }
        var name = ""
        for character in body.dropFirst() {
            if character == "/" && name.isEmpty { continue }
            if character.isLetter || character.isNumber { name.append(character) } else { break }
        }
        return htmlBlockTags.contains(name.lowercased())
    }

    // MARK: Link definitions

    static let definition = /^ {0,3}\[([^\]\n]+)\]:\s*<?([^\s>]+)>?(?:\s+(?:"([^"]*)"|'([^']*)'|\(([^)]*)\)))?\s*$/

    static func normalisedLabel(_ label: String) -> String {
        label.lowercased().split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}
