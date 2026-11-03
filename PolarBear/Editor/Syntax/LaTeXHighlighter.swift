//
//  LaTeXHighlighter.swift
//  PolarBear
//

/// Splits LaTeX source into coloured tokens, one line at a time.
enum LaTeXHighlighter {
    private static let argumentCommands: Set<String> = ["begin", "end", "usepackage", "documentclass"]

    /// Splits one source line into consecutive tokens that cover the whole line.
    /// `inMath` carries display-math state from one line to the next.
    static func tokens(in line: String, inMath: inout Bool) -> [LaTeXToken] {
        var output: [LaTeXToken] = []

        func add(_ string: String, _ kind: LaTeXTokenKind) {
            guard !string.isEmpty else { return }
            output.append(LaTeXToken(length: string.utf16.count, kind: kind))
        }

        let chars = Array(line)
        let count = chars.count

        if let first = chars.first(where: { !$0.isWhitespace }), first == "%" {
            add(line, .comment)
            return output
        }

        var plain = ""
        func flush() {
            add(plain, .text)
            plain = ""
        }

        var expectsArgument = false
        var index = 0

        while index < count {
            let char = chars[index]
            switch char {
            case "\\":
                flush()
                var end = index + 1
                if end < count, chars[end].isLetter {
                    while end < count, chars[end].isLetter { end += 1 }
                    if end < count, chars[end] == "*" { end += 1 }
                } else if end < count {
                    end += 1
                }
                let token = String(chars[index..<end])
                let name = String(token.dropFirst().filter(\.isLetter))
                let isWord = token.dropFirst().first?.isLetter == true

                switch token {
                case "\\[":
                    inMath = true
                    add(token, .text)
                case "\\]":
                    inMath = false
                    add(token, .text)
                case "\\{", "\\}":
                    add(token, .bracket)
                default:
                    add(token, (inMath && isWord) ? .math : .text)
                }
                expectsArgument = argumentCommands.contains(name)
                index = end

            case "{", "[":
                flush()
                if expectsArgument {
                    let closing: Character = (char == "{") ? "}" : "]"
                    if let close = chars[(index + 1)...].firstIndex(of: closing) {
                        add(String(char), .bracket)
                        add(String(chars[(index + 1)..<close]), .argument)
                        add(String(closing), .bracket)
                        index = close + 1
                        continue
                    }
                }
                add(String(char), .bracket)
                expectsArgument = false
                index += 1

            case "}", "]":
                flush()
                add(String(char), .bracket)
                expectsArgument = false
                index += 1

            case "$":
                inMath.toggle()
                plain.append(char)
                expectsArgument = false
                index += 1

            default:
                plain.append(char)
                expectsArgument = false
                index += 1
            }
        }
        flush()
        return output
    }
}
