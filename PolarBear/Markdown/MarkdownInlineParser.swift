//
//  MarkdownInlineParser.swift
//  PolarBear
//

import Foundation

/// Parses the text of a heading, paragraph or table cell: code spans, emphasis (`*`, `_`),
/// strikethrough (`~~`), links, images, autolinks, entities and line breaks. Emphasis follows
/// CommonMark's delimiter-run rules.
nonisolated struct MarkdownInlineParser {
    static func parse(
        _ text: String,
        definitions: [String: MarkdownDocument.LinkDefinition],
        footnoteIDs: Set<String> = []
    ) -> [MarkdownInline] {
        var parser = MarkdownInlineParser(characters: Array(text), definitions: definitions, footnoteIDs: footnoteIDs)
        return parser.run()
    }

    // MARK: State

    private enum Node {
        case inline(MarkdownInline)
        case run(Run)
        /// The `[` or `![` that may start a link; `start` is where its text begins.
        case opener(isImage: Bool, isActive: Bool, start: Int)
    }

    private struct Run {
        var character: Character
        var count: Int
        let original: Int
        let canOpen: Bool
        let canClose: Bool
    }

    private let characters: [Character]
    private let definitions: [String: MarkdownDocument.LinkDefinition]
    private let footnoteIDs: Set<String>
    private var nodes: [Node] = []
    private var buffer = ""
    private var index = 0

    private init(characters: [Character], definitions: [String: MarkdownDocument.LinkDefinition], footnoteIDs: Set<String>) {
        self.characters = characters
        self.definitions = definitions
        self.footnoteIDs = footnoteIDs
    }

    private var count: Int { characters.count }

    // MARK: Scanning

    private mutating func run() -> [MarkdownInline] {
        while index < count {
            let character = characters[index]
            switch character {
            case "\\": escape()
            case "`": codeSpan()
            case "*", "_", "~", "=": delimiterRun(character)
            case ":": emojiShortcode()
            case "[":
                if !footnoteReference() {
                    flush()
                    nodes.append(.opener(isImage: false, isActive: true, start: index + 1))
                    index += 1
                }
            case "$": math()
            case "!":
                if index + 1 < count, characters[index + 1] == "[" {
                    flush()
                    nodes.append(.opener(isImage: true, isActive: true, start: index + 2))
                    index += 2
                } else {
                    buffer.append(character)
                    index += 1
                }
            case "]": closeBracket()
            case "<": angle()
            case "&": entity()
            case "\n": lineEnd()
            case "h", "w", "H", "W": bareLink()
            default:
                buffer.append(character)
                index += 1
            }
        }
        flush()
        return Self.resolve(nodes)
    }

    private mutating func flush() {
        guard !buffer.isEmpty else { return }
        nodes.append(.inline(.text(buffer)))
        buffer = ""
    }

    private mutating func append(_ inline: MarkdownInline) {
        flush()
        nodes.append(.inline(inline))
    }

    // MARK: Escapes, code, breaks

    private mutating func escape() {
        guard index + 1 < count else {
            buffer.append("\\")
            index += 1
            return
        }
        let next = characters[index + 1]
        if next == "\n" {
            trimTrailingSpaces()
            append(.lineBreak)
            index += 2
            skipLeadingSpaces()
        } else if next == "(", let close = findInlineMathClose(from: index + 2) {
            append(.math(String(characters[(index + 2)..<close]).trimmingCharacters(in: .whitespacesAndNewlines)))
            index = close + 2
        } else if next.isASCII, next.isPunctuation || next.isSymbol {
            buffer.append(next)
            index += 2
        } else {
            buffer.append("\\")
            index += 1
        }
    }

    private mutating func codeSpan() {
        var length = 0
        while index + length < count, characters[index + length] == "`" { length += 1 }
        var scan = index + length
        while scan < count {
            if characters[scan] == "`" {
                var run = 0
                while scan + run < count, characters[scan + run] == "`" { run += 1 }
                if run == length {
                    var content = String(characters[(index + length)..<scan]).replacing("\n", with: " ")
                    if content.hasPrefix(" "), content.hasSuffix(" "), content.contains(where: { $0 != " " }) {
                        content = String(content.dropFirst().dropLast())
                    }
                    append(.code(content))
                    index = scan + run
                    return
                }
                scan += run
            } else {
                scan += 1
            }
        }
        buffer.append(String(repeating: "`", count: length))
        index += length
    }

    private mutating func lineEnd() {
        let hardBreak = buffer.hasSuffix("  ")
        trimTrailingSpaces()
        append(hardBreak ? .lineBreak : .softBreak)
        index += 1
        skipLeadingSpaces()
    }

    private mutating func trimTrailingSpaces() {
        while buffer.hasSuffix(" ") { buffer.removeLast() }
    }

    private mutating func skipLeadingSpaces() {
        while index < count, characters[index] == " " { index += 1 }
    }

    // MARK: Emphasis delimiters

    private mutating func delimiterRun(_ character: Character) {
        var length = 0
        while index + length < count, characters[index + length] == character { length += 1 }
        if (character == "~" && length > 2) || (character == "=" && length != 2) {
            buffer.append(String(repeating: character, count: length))
            index += length
            return
        }

        let before = index > 0 ? characters[index - 1] : "\n"
        let afterIndex = index + length
        let after = afterIndex < count ? characters[afterIndex] : "\n"
        let beforeSpace = before.isWhitespace, afterSpace = after.isWhitespace
        let beforePunctuation = Self.isPunctuation(before), afterPunctuation = Self.isPunctuation(after)

        let leftFlanking = !afterSpace && (!afterPunctuation || beforeSpace || beforePunctuation)
        let rightFlanking = !beforeSpace && (!beforePunctuation || afterSpace || afterPunctuation)

        let canOpen: Bool, canClose: Bool
        if character == "_" {
            canOpen = leftFlanking && (!rightFlanking || beforePunctuation)
            canClose = rightFlanking && (!leftFlanking || afterPunctuation)
        } else {
            canOpen = leftFlanking
            canClose = rightFlanking
        }

        if !canOpen && !canClose {
            buffer.append(String(repeating: character, count: length))
        } else {
            flush()
            nodes.append(.run(Run(character: character, count: length, original: length, canOpen: canOpen, canClose: canClose)))
        }
        index += length
    }

    private static func isPunctuation(_ character: Character) -> Bool {
        character.isPunctuation || character.isSymbol
    }

    // MARK: Footnotes, maths and emoji

    /// The index of the backslash of the `\)` that closes a `\(` formula.
    private func findInlineMathClose(from start: Int) -> Int? {
        var scan = start
        while scan + 1 < count {
            if characters[scan] == "\\", characters[scan + 1] == ")" { return scan }
            if characters[scan] == "\n", characters[scan + 1] == "\n" { return nil }
            scan += 1
        }
        return nil
    }

    /// `:tada:`
    private mutating func emojiShortcode() {
        let previous = index > 0 ? characters[index - 1] : " "
        if !previous.isLetter, !previous.isNumber,
           let close = characters[(index + 1)..<min(count, index + 32)].firstIndex(of: ":"), close > index + 1,
           let emoji = MarkdownEmoji.character(for: String(characters[(index + 1)..<close])) {
            buffer.append(emoji)
            index = close + 1
        } else {
            buffer.append(":")
            index += 1
        }
    }

    /// `[^name]` for a footnote that is defined.
    private mutating func footnoteReference() -> Bool {
        guard index + 2 < count, characters[index + 1] == "^",
              let close = characters[(index + 2)...].firstIndex(of: "]")
        else { return false }
        let name = String(characters[(index + 2)..<close])
        guard footnoteIDs.contains(name) else { return false }
        append(.footnote(name))
        index = close + 1
        return true
    }

    /// `$x^2$`: the dollar signs must hug the formula, and the closing one must not touch a digit,
    /// so "costs $5 and $10" stays text.
    private mutating func math() {
        let isDisplay = index + 1 < count && characters[index + 1] == "$"
        let delimiter = isDisplay ? 2 : 1
        let start = index + delimiter
        guard start < count, !characters[start].isWhitespace || isDisplay else {
            buffer.append("$")
            index += 1
            return
        }
        var scan = start
        while scan < count {
            if characters[scan] == "\\" { scan += 2; continue }
            let touchesAnotherDollar = !isDisplay && ((scan + 1 < count && characters[scan + 1] == "$") || characters[scan - 1] == "$")
            if characters[scan] == "$", !touchesAnotherDollar, (!isDisplay || (scan + 1 < count && characters[scan + 1] == "$")) {
                let end = scan
                let afterIndex = scan + delimiter
                let nextIsDigit = afterIndex < count && characters[afterIndex].isNumber
                if end > start, isDisplay || (!characters[end - 1].isWhitespace && !nextIsDigit) {
                    append(.math(String(characters[start..<end]).trimmingCharacters(in: .whitespacesAndNewlines)))
                    index = afterIndex
                    return
                }
            }
            scan += 1
        }
        buffer.append(String(repeating: "$", count: delimiter))
        index += delimiter
    }

    // MARK: Links and images

    private mutating func closeBracket() {
        flush()
        guard let openerIndex = nodes.lastIndex(where: { if case .opener = $0 { true } else { false } }),
              case .opener(let isImage, let isActive, let start) = nodes[openerIndex]
        else {
            buffer.append("]")
            index += 1
            return
        }
        if !isActive {
            nodes[openerIndex] = .inline(.text(isImage ? "![" : "["))
            buffer.append("]")
            index += 1
            return
        }

        let after = index + 1
        var destination: String?, title: String?, end = after

        if after < count, characters[after] == "(", let tail = inlineLinkTail(at: after) {
            destination = tail.destination
            title = tail.title
            end = tail.end
        } else {
            let text = String(characters[start..<index])
            var label = text
            var labelEnd = after
            if after < count, characters[after] == "[", let close = characters[(after + 1)...].firstIndex(of: "]") {
                let explicit = String(characters[(after + 1)..<close])
                if !explicit.isEmpty { label = explicit }
                labelEnd = close + 1
            }
            if let definition = definitions[MarkdownLines.normalisedLabel(label)] {
                destination = definition.destination
                title = definition.title
                end = labelEnd
            }
        }

        guard let destination else {
            nodes[openerIndex] = .inline(.text(isImage ? "![" : "["))
            buffer.append("]")
            index += 1
            return
        }

        let children = Self.resolve(Array(nodes[(openerIndex + 1)...]))
        nodes.removeSubrange(openerIndex...)
        if isImage {
            nodes.append(.inline(.image(source: destination, title: title, alt: MarkdownInline.plainText(of: children))))
        } else {
            nodes.append(.inline(.link(destination: destination, title: title, content: children)))
            // A link cannot contain another link.
            for position in nodes.indices {
                if case .opener(let image, _, let openerStart) = nodes[position], !image {
                    nodes[position] = .opener(isImage: false, isActive: false, start: openerStart)
                }
            }
        }
        index = end
    }

    /// `(destination "title")` starting at the `(` at `position`.
    private func inlineLinkTail(at position: Int) -> (destination: String, title: String?, end: Int)? {
        var cursor = position + 1
        func skipSpaces() {
            while cursor < count, characters[cursor] == " " || characters[cursor] == "\n" { cursor += 1 }
        }
        skipSpaces()

        var destination = ""
        if cursor < count, characters[cursor] == "<" {
            cursor += 1
            while cursor < count, characters[cursor] != ">", characters[cursor] != "\n" {
                destination.append(characters[cursor])
                cursor += 1
            }
            guard cursor < count, characters[cursor] == ">" else { return nil }
            cursor += 1
        } else {
            var depth = 0
            while cursor < count {
                let character = characters[cursor]
                if character == "\\", cursor + 1 < count {
                    destination.append(characters[cursor + 1])
                    cursor += 2
                    continue
                }
                if character == " " || character == "\n" { break }
                if character == "(" { depth += 1 }
                if character == ")" {
                    if depth == 0 { break }
                    depth -= 1
                }
                destination.append(character)
                cursor += 1
            }
        }

        skipSpaces()
        var title: String?
        if cursor < count, characters[cursor] == "\"" || characters[cursor] == "'" || characters[cursor] == "(" {
            let opening = characters[cursor]
            let closing: Character = opening == "(" ? ")" : opening
            cursor += 1
            var value = ""
            while cursor < count, characters[cursor] != closing {
                if characters[cursor] == "\\", cursor + 1 < count {
                    value.append(characters[cursor + 1])
                    cursor += 2
                } else {
                    value.append(characters[cursor])
                    cursor += 1
                }
            }
            guard cursor < count else { return nil }
            cursor += 1
            title = value
            skipSpaces()
        }
        guard cursor < count, characters[cursor] == ")" else { return nil }
        return (destination, title, cursor + 1)
    }

    // MARK: Autolinks, HTML, entities

    private mutating func angle() {
        let window = String(characters[index..<min(count, index + 400)])
        if let match = window.prefixMatch(of: /<([A-Za-z][A-Za-z0-9+.\-]{1,31}:[^\s<>]*)>/) {
            let address = String(match.1)
            append(.link(destination: address, title: nil, content: [.text(address)]))
            index += match.0.count
        } else if let match = window.prefixMatch(of: /<([A-Za-z0-9.!#$%&'*+\/=?^_`{|}~\-]+@[A-Za-z0-9\-]+(?:\.[A-Za-z0-9\-]+)*)>/) {
            let address = String(match.1)
            append(.link(destination: "mailto:" + address, title: nil, content: [.text(address)]))
            index += match.0.count
        } else if let match = window.prefixMatch(of: /<!--[\s\S]*?-->|<\/?[A-Za-z][A-Za-z0-9\-]*(?:\s+[^<>]*?)?\/?>/) {
            append(.html(String(match.0)))
            index += match.0.count
        } else {
            buffer.append("<")
            index += 1
        }
    }

    private static let entities: [String: String] = [
        "amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'", "nbsp": "\u{00A0}", "copy": "©", "reg": "®",
        "trade": "™", "hellip": "…", "mdash": "—", "ndash": "–", "lsquo": "‘", "rsquo": "’", "ldquo": "“",
        "rdquo": "”", "times": "×", "deg": "°", "middot": "·", "bull": "•", "euro": "€", "pound": "£",
        "asymp": "≈", "ne": "≠", "le": "≤", "ge": "≥", "plusmn": "±", "infin": "∞", "larr": "←", "rarr": "→",
        "uarr": "↑", "darr": "↓", "harr": "↔", "lArr": "⇐", "rArr": "⇒", "hArr": "⇔", "hearts": "♥", "spades": "♠",
        "clubs": "♣", "diams": "♦", "check": "✓", "cent": "¢", "yen": "¥", "sect": "§", "para": "¶", "laquo": "«",
        "raquo": "»", "divide": "÷", "minus": "−", "micro": "µ", "frac12": "½", "frac14": "¼", "frac34": "¾",
        "sup1": "¹", "sup2": "²", "sup3": "³", "alpha": "α", "beta": "β", "gamma": "γ", "delta": "δ", "pi": "π",
        "sigma": "σ", "omega": "ω", "lambda": "λ", "mu": "μ", "theta": "θ", "sum": "∑", "prod": "∏", "radic": "√",
        "int": "∫", "part": "∂", "nabla": "∇", "forall": "∀", "exist": "∃", "isin": "∈", "cap": "∩", "cup": "∪",
        "and": "∧", "or": "∨", "not": "¬", "equiv": "≡", "dagger": "†", "Dagger": "‡", "permil": "‰", "prime": "′",
        "Prime": "″", "oline": "‾", "ensp": "\u{2002}", "emsp": "\u{2003}", "thinsp": "\u{2009}", "shy": "\u{00AD}",
        "iexcl": "¡", "iquest": "¿", "szlig": "ß", "aacute": "á", "eacute": "é", "iacute": "í", "oacute": "ó",
        "uacute": "ú", "agrave": "à", "egrave": "è", "ntilde": "ñ", "uuml": "ü", "ouml": "ö", "auml": "ä",
    ]

    private mutating func entity() {
        let window = String(characters[index..<min(count, index + 12)])
        if let match = window.prefixMatch(of: /&(#[0-9]{1,7}|#[xX][0-9a-fA-F]{1,6}|[A-Za-z][A-Za-z0-9]{1,8});/) {
            let name = String(match.1)
            var decoded: String?
            if name.hasPrefix("#x") || name.hasPrefix("#X") {
                decoded = UInt32(name.dropFirst(2), radix: 16).flatMap(Unicode.Scalar.init).map { String(Character($0)) }
            } else if name.hasPrefix("#") {
                decoded = UInt32(name.dropFirst()).flatMap(Unicode.Scalar.init).map { String(Character($0)) }
            } else {
                decoded = Self.entities[name]
            }
            if let decoded {
                buffer.append(decoded)
                index += match.0.count
                return
            }
        }
        buffer.append("&")
        index += 1
    }

    /// `https://example.com` and `www.example.com` written without brackets.
    private mutating func bareLink() {
        let previous = index > 0 ? characters[index - 1] : " "
        let window = String(characters[index..<min(count, index + 600)])
        guard !previous.isLetter, !previous.isNumber,
              window.lowercased().hasPrefix("http://") || window.lowercased().hasPrefix("https://") || window.lowercased().hasPrefix("www.")
        else {
            buffer.append(characters[index])
            index += 1
            return
        }
        var address = String(window.prefix(while: { !$0.isWhitespace && $0 != "<" }))
        while let last = address.last, ".,;:!?\"'*_~".contains(last) { address.removeLast() }
        while address.hasSuffix(")"), address.filter({ $0 == ")" }).count > address.filter({ $0 == "(" }).count { address.removeLast() }
        guard address.count > 6 else {
            buffer.append(characters[index])
            index += 1
            return
        }
        let destination = address.lowercased().hasPrefix("www.") ? "https://" + address : address
        append(.link(destination: destination, title: nil, content: [.text(address)]))
        index += address.count
    }

    // MARK: Resolving emphasis

    /// Matches the delimiter runs of `nodes` into emphasis, strong and strikethrough, and turns
    /// everything left over into text.
    private static func resolve(_ source: [Node]) -> [MarkdownInline] {
        var items = source
        var closer = 0

        while closer < items.count {
            guard case .run(var closing) = items[closer], closing.canClose else {
                closer += 1
                continue
            }

            var opener = closer - 1
            var matched = false
            while opener >= 0 {
                if case .run(var opening) = items[opener], opening.canOpen, opening.character == closing.character {
                    let oddMatch = (opening.canClose || closing.canOpen)
                        && (opening.original + closing.original) % 3 == 0
                        && !(opening.original % 3 == 0 && closing.original % 3 == 0)
                    if !oddMatch {
                        let use = (opening.count >= 2 && closing.count >= 2) ? 2 : 1
                        let content = inlines(from: Array(items[(opener + 1)..<closer]))
                        let wrapped: MarkdownInline
                        if closing.character == "~" {
                            wrapped = .strikethrough(content)
                        } else if closing.character == "=" {
                            wrapped = .highlight(content)
                        } else {
                            wrapped = use == 2 ? .strong(content) : .emphasis(content)
                        }
                        opening.count -= use
                        closing.count -= use

                        items.replaceSubrange((opener + 1)..<closer, with: [.inline(wrapped)])
                        closer = opener + 2
                        items[opener] = .run(opening)
                        items[closer] = .run(closing)
                        if closing.count == 0 {
                            items.remove(at: closer)
                        }
                        if opening.count == 0 {
                            items.remove(at: opener)
                            closer -= 1
                        }
                        matched = true
                        break
                    }
                }
                opener -= 1
            }
            if !matched { closer += 1 }
        }
        return inlines(from: items)
    }

    /// Delimiters and brackets that found no partner become text; neighbouring text is merged.
    private static func inlines(from nodes: [Node]) -> [MarkdownInline] {
        var result: [MarkdownInline] = []
        func add(_ inline: MarkdownInline) {
            if case .text(let new) = inline, case .text(let old)? = result.last {
                result[result.count - 1] = .text(old + new)
            } else {
                result.append(inline)
            }
        }
        for node in nodes {
            switch node {
            case .inline(let inline): add(inline)
            case .run(let run): if run.count > 0 { add(.text(String(repeating: run.character, count: run.count))) }
            case .opener(let isImage, _, _): add(.text(isImage ? "![" : "["))
            }
        }
        return result
    }
}
