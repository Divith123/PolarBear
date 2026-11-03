//
//  MarkdownHighlighter.swift
//  PolarBear
//

/// Splits Markdown source into coloured tokens, one line at a time. `inFence` carries the
/// "inside a fenced code block" state from one line to the next.
enum MarkdownHighlighter {
    static func tokens(in line: String, inFence: inout Bool) -> [LaTeXToken] {
        var output: [LaTeXToken] = []
        func add(_ length: Int, _ kind: LaTeXTokenKind) {
            guard length > 0 else { return }
            output.append(LaTeXToken(length: length, kind: kind))
        }
        let total = line.utf16.count

        if MarkdownLines.fenceStart(line) != nil {
            inFence.toggle()
            add(total, .code)
            return output
        }
        if inFence {
            add(total, .code)
            return output
        }
        if MarkdownLines.atxHeading(line) != nil {
            add(total, .heading)
            return output
        }
        if MarkdownLines.isThematicBreak(line) {
            add(total, .marker)
            return output
        }
        if MarkdownLines.isQuote(line) {
            add(total, .quote)
            return output
        }

        // A list marker at the start of the line.
        var body = Substring(line)
        let indent = line.prefix(while: { $0 == " " }).count
        if MarkdownLines.listMarker(line) != nil {
            let markerLength = line.dropFirst(indent).prefix(while: { $0 != " " }).count
            add(indent, .text)
            add(markerLength, .marker)
            body = body.dropFirst(indent + markerLength)
        }

        inlineTokens(Array(body), add: add)
        return output
    }

    /// Code spans, bold, italic and links inside a line.
    private static func inlineTokens(_ characters: [Character], add: (Int, LaTeXTokenKind) -> Void) {
        var index = 0
        var plain = 0
        func flush() {
            add(plain, .text)
            plain = 0
        }
        func units(_ range: Range<Int>) -> Int {
            characters[range].reduce(0) { $0 + String($1).utf16.count }
        }

        while index < characters.count {
            let character = characters[index]
            var consumed: (end: Int, kind: LaTeXTokenKind)?

            switch character {
            case "`":
                let run = characters[index...].prefix(while: { $0 == "`" }).count
                if let close = findRun(of: "`", length: run, in: characters, from: index + run) {
                    consumed = (close + run, .code)
                }
            case "*", "_":
                let run = min(characters[index...].prefix(while: { $0 == character }).count, 3)
                let startsWord = index == 0 || !characters[index - 1].isLetter && !characters[index - 1].isNumber || character == "*"
                if startsWord, index + run < characters.count, !characters[index + run].isWhitespace,
                   let close = findRun(of: character, length: run, in: characters, from: index + run),
                   !characters[close - 1].isWhitespace {
                    consumed = (close + run, .emphasis)
                }
            case "[":
                if let close = characters[index...].firstIndex(of: "]"), close + 1 < characters.count, characters[close + 1] == "(",
                   let end = characters[(close + 1)...].firstIndex(of: ")") {
                    consumed = (end + 1, .link)
                }
            case "!":
                break
            default:
                break
            }

            if let consumed {
                flush()
                add(units(index..<consumed.end), consumed.kind)
                index = consumed.end
            } else {
                plain += String(character).utf16.count
                index += 1
            }
        }
        flush()
    }

    private static func findRun(of character: Character, length: Int, in characters: [Character], from start: Int) -> Int? {
        var index = start
        while index < characters.count {
            if characters[index] == character {
                let run = characters[index...].prefix(while: { $0 == character }).count
                if run >= length { return index }
                index += run
            } else {
                index += 1
            }
        }
        return nil
    }
}
