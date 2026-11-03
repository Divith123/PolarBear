//
//  DocumentStatsCounter.swift
//  PolarBear
//

import Foundation

/// Counts words and elements in LaTeX source: the running text, section titles, captions,
/// figures, headers and maths. `\input` and `\include` are followed.
nonisolated enum DocumentStatsCounter {
    private static let headingCommands: Set<String> = [
        "part", "chapter", "section", "subsection", "subsubsection", "paragraph", "subparagraph",
    ]
    /// Commands whose braced argument is not text of the document.
    private static let silentCommands: Set<String> = [
        "label", "ref", "eqref", "pageref", "autoref", "cref", "Cref", "cite", "citep", "citet", "citeauthor",
        "citeyear", "nocite", "usepackage", "RequirePackage", "documentclass", "include", "input", "includegraphics",
        "bibliography", "bibliographystyle", "url", "hspace", "vspace", "newcommand", "renewcommand", "setlength",
        "pagestyle", "thispagestyle", "usetheme", "usetikzlibrary", "includeonly", "href",
    ]
    private static let mathEnvironments: Set<String> = [
        "equation", "equation*", "align", "align*", "gather", "gather*", "multline", "multline*",
        "eqnarray", "eqnarray*", "displaymath", "flalign", "flalign*",
    ]
    private static let verbatimEnvironments: Set<String> = ["verbatim", "verbatim*", "lstlisting", "minted", "comment"]

    /// Counts off the main actor.
    @concurrent
    static func compute(root: String, sources: [String: String]) async -> DocumentStats {
        count(root: root, sources: sources)
    }

    /// Counts the document that starts at `root`.
    static func count(root: String, sources: [String: String]) -> DocumentStats {
        var scanner = Scanner(Array(expand(root, sources: sources, depth: 0, visited: [])))
        scanner.run()
        return scanner.stats
    }

    // MARK: Includes

    private static func expand(_ path: String, sources: [String: String], depth: Int, visited: Set<String>) -> String {
        guard depth < 8, !visited.contains(path), let text = sources[path] else { return "" }
        var result = ""
        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            if let match = line.firstMatch(of: /^\s*\\(?:input|include)\{([^}]+)\}/) {
                let name = String(match.1)
                let target = sources[name] != nil ? name : name + ".tex"
                result += expand(target, sources: sources, depth: depth + 1, visited: visited.union([path])) + "\n"
            } else {
                result += line + "\n"
            }
        }
        return result
    }

    // MARK: Scanning

    private struct Scanner {
        let chars: [Character]
        var index = 0
        var stats = DocumentStats()
        var inBody: Bool

        init(_ chars: [Character]) {
            self.chars = chars
            let text = String(chars)
            inBody = !text.contains("\\begin{document}")
        }

        mutating func run() {
            var word = ""

            func flush(_ stats: inout DocumentStats) {
                if word.contains(where: \.isLetter) || word.contains(where: \.isNumber) {
                    stats.wordsInText += 1
                }
                word = ""
            }

            while index < chars.count {
                let char = chars[index]
                switch char {
                case "%":
                    flush(&stats)
                    skipLine()
                case "$":
                    flush(&stats)
                    skipDollarMath()
                case "\\":
                    flush(&stats)
                    handleCommand()
                case "{", "}", "[", "]", "~":
                    flush(&stats)
                    index += 1
                case let c where c.isLetter || c.isNumber || ((c == "'" || c == "-" || c == "’") && !word.isEmpty):
                    if inBody { word.append(c) }
                    index += 1
                default:
                    flush(&stats)
                    index += 1
                }
            }
            flush(&stats)
        }

        private mutating func skipLine() {
            while index < chars.count, chars[index] != "\n" { index += 1 }
        }

        private mutating func skipDollarMath() {
            let isDisplay = index + 1 < chars.count && chars[index + 1] == "$"
            index += isDisplay ? 2 : 1
            while index < chars.count {
                if chars[index] == "\\" { index += 2; continue }
                if chars[index] == "$" {
                    index += isDisplay && index + 1 < chars.count && chars[index + 1] == "$" ? 2 : 1
                    break
                }
                index += 1
            }
            if inBody { if isDisplay { stats.displayedMath += 1 } else { stats.inlineMath += 1 } }
        }

        private mutating func handleCommand() {
            index += 1
            guard index < chars.count else { return }

            // Control symbols: \\ \% \$ \( \) \[ \] …
            if !chars[index].isLetter {
                let symbol = chars[index]
                index += 1
                if symbol == "(" || symbol == "[" {
                    skipUntil(closing: symbol == "(" ? "\\)" : "\\]")
                    if inBody { if symbol == "(" { stats.inlineMath += 1 } else { stats.displayedMath += 1 } }
                }
                return
            }

            var name = ""
            while index < chars.count, chars[index].isLetter { name.append(chars[index]); index += 1 }
            if index < chars.count, chars[index] == "*" { name.append("*"); index += 1 }
            let bare = name.hasSuffix("*") ? String(name.dropLast()) : name

            if name == "begin" {
                beginEnvironment()
            } else if name == "end" {
                _ = readGroup()
            } else if bare == "document" {
                return
            } else if DocumentStatsCounter.headingCommands.contains(bare) {
                skipOptional()
                if let title = readGroup() {
                    if inBody {
                        stats.headers += 1
                        stats.wordsInHeaders += DocumentStatsCounter.words(in: title)
                    }
                }
            } else if bare == "caption" || bare == "footnote" {
                skipOptional()
                if let text = readGroup(), inBody {
                    stats.wordsOutsideText += DocumentStatsCounter.words(in: text)
                }
            } else if DocumentStatsCounter.silentCommands.contains(bare) {
                skipOptional()
                _ = readGroup()
            }
        }

        private mutating func beginEnvironment() {
            skipOptional()
            guard let name = readGroup() else { return }
            if name == "document" {
                inBody = true
            } else if DocumentStatsCounter.mathEnvironments.contains(name) {
                skipUntil(closing: "\\end{\(name)}")
                if inBody { stats.displayedMath += 1 }
            } else if DocumentStatsCounter.verbatimEnvironments.contains(name) {
                skipUntil(closing: "\\end{\(name)}")
            } else if name.hasPrefix("figure") {
                if inBody { stats.figures += 1 }
                skipOptional()
            } else {
                skipOptional()
            }
        }

        /// Skips `[…]` if one follows.
        private mutating func skipOptional() {
            var look = index
            while look < chars.count, chars[look] == " " { look += 1 }
            guard look < chars.count, chars[look] == "[" else { return }
            var depth = 0
            while look < chars.count {
                if chars[look] == "[" { depth += 1 }
                if chars[look] == "]" { depth -= 1; if depth == 0 { look += 1; break } }
                look += 1
            }
            index = look
        }

        /// Reads `{…}` (balanced) and returns its content.
        private mutating func readGroup() -> String? {
            var look = index
            while look < chars.count, chars[look] == " " { look += 1 }
            guard look < chars.count, chars[look] == "{" else { return nil }
            var depth = 0
            var content = ""
            while look < chars.count {
                let char = chars[look]
                if char == "\\", look + 1 < chars.count {
                    content.append(char)
                    content.append(chars[look + 1])
                    look += 2
                    continue
                }
                if char == "{" { depth += 1; if depth == 1 { look += 1; continue } }
                if char == "}" { depth -= 1; if depth == 0 { look += 1; break } }
                content.append(char)
                look += 1
            }
            index = look
            return content
        }

        private mutating func skipUntil(closing: String) {
            let pattern = Array(closing)
            while index < chars.count {
                if chars[index] == pattern[0], index + pattern.count <= chars.count,
                   Array(chars[index..<(index + pattern.count)]) == pattern {
                    index += pattern.count
                    return
                }
                index += 1
            }
        }
    }

    /// Words in a snippet of LaTeX (commands and maths left out).
    static func words(in snippet: String) -> Int {
        var scanner = Scanner(Array(snippet))
        scanner.inBody = true
        scanner.run()
        return scanner.stats.wordsInText
    }
}
