//
//  CodeHighlighter.swift
//  PolarBear
//

import Foundation

/// Colours the code of a fenced block: keywords, strings, comments, numbers, types and calls
/// get their own HTML classes (see `MarkdownPage`). One small scanner serves the C-like
/// languages, Python, shell, SQL, JSON, YAML, HTML, CSS and diffs; an unknown language is shown
/// uncoloured.
nonisolated enum CodeHighlighter {
    /// The code as HTML with `<span class="tok-…">` runs, or `nil` for a language without rules.
    static func html(_ code: String, language: String?) -> String? {
        guard let name = language?.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "{}. ")),
              let family = Family(language: name)
        else { return nil }
        switch family {
        case .diff: return diff(code)
        case .markup: return markup(code)
        case .json:
            var scanner = Scanner(code, rules: .json)
            return scanner.run()
        case .yaml: return yaml(code)
        case .css: return css(code)
        case .generic(let rules):
            var scanner = Scanner(code, rules: rules)
            return scanner.run()
        }
    }

    // MARK: Languages

    private enum Family {
        case generic(Rules)
        case json, yaml, diff, markup, css

        init?(language: String) {
            switch language {
            case "swift": self = .generic(.swift)
            case "rust", "rs": self = .generic(.rust)
            case "ts", "typescript", "tsx": self = .generic(.typescript)
            case "js", "javascript", "jsx", "mjs", "cjs": self = .generic(.javascript)
            case "py", "python", "python3": self = .generic(.python)
            case "sql", "postgres", "postgresql", "mysql", "sqlite": self = .generic(.sql)
            case "sh", "bash", "zsh", "shell", "console", "fish": self = .generic(.shell)
            case "c", "h", "cpp", "c++", "cc", "hpp", "cxx", "objc", "objective-c", "cs", "csharp":
                self = .generic(.cLike)
            case "java", "kotlin", "kt", "scala", "dart": self = .generic(.java)
            case "go", "golang": self = .generic(.go)
            case "rb", "ruby": self = .generic(.ruby)
            case "php": self = .generic(.php)
            case "lua": self = .generic(.lua)
            case "toml", "ini", "conf": self = .generic(.toml)
            case "latex", "tex": self = .generic(.tex)
            case "json", "jsonc", "json5": self = .json
            case "yaml", "yml": self = .yaml
            case "diff", "patch": self = .diff
            case "html", "xml", "svg", "xhtml", "plist", "vue": self = .markup
            case "css", "scss", "less": self = .css
            default: return nil
            }
        }
    }

    struct Rules {
        var keywords: Set<String>
        var constants: Set<String> = []
        var lineComments: [String] = ["//"]
        var blockComment: (open: String, close: String)? = ("/*", "*/")
        var stringQuotes: [Character] = ["\"", "'"]
        /// Quotes whose strings may continue over several lines (`` ` ``, `"""`).
        var multilineQuotes: [Character] = ["`"]
        var tripleQuotes = false
        var isCaseInsensitive = false
        /// A capitalised word is a type.
        var capitalisedIsType = true
        var variablePrefix: Character?
        /// `@name` is an attribute / decorator.
        var atWordIsAttribute = false
        /// `#name` starts a directive (`#include`, `#[derive]`).
        var hashWordIsDirective = false
        /// A string followed by `:` is a key (JSON).
        var highlightsKeys = false
    }

    // MARK: Scanner

    private struct Scanner {
        let characters: [Character]
        let rules: Rules
        var output = ""
        var index = 0

        init(_ code: String, rules: Rules) {
            characters = Array(code)
            self.rules = rules
        }

        mutating func run() -> String {
            while index < characters.count {
                let character = characters[index]

                if let comment = matchComment() {
                    emit(comment, "com")
                } else if let quote = stringQuote(at: index) {
                    let text = readString(quote)
                    emit(text, rules.highlightsKeys && followedByColon() ? "attr" : "str")
                } else if character.isNumber || (character == "." && next(1)?.isNumber == true) {
                    emit(readNumber(), "num")
                } else if let prefix = rules.variablePrefix, character == prefix, next(1).map({ $0.isLetter || $0 == "_" || $0 == "{" || $0 == "(" }) == true {
                    emit(readVariable(), "var")
                } else if rules.atWordIsAttribute, character == "@", next(1)?.isLetter == true {
                    emit(readWord(from: index + 1, prefix: "@"), "attr")
                } else if rules.hashWordIsDirective, character == "#", next(1)?.isLetter == true || next(1) == "[" {
                    emit(readDirective(), "attr")
                } else if character.isLetter || character == "_" || character == "$" {
                    word()
                } else {
                    plain(String(character))
                    index += 1
                }
            }
            return output
        }

        private func followedByColon() -> Bool {
            var position = index
            while position < characters.count, characters[position] == " " { position += 1 }
            return position < characters.count && characters[position] == ":"
        }

        private func next(_ offset: Int) -> Character? {
            index + offset < characters.count ? characters[index + offset] : nil
        }

        private func has(_ text: String, at position: Int) -> Bool {
            let chars = Array(text)
            guard position + chars.count <= characters.count else { return false }
            for (offset, character) in chars.enumerated() where characters[position + offset] != character { return false }
            return true
        }

        private mutating func emit(_ text: String, _ kind: String) {
            output += "<span class=\"tok-\(kind)\">\(MarkdownHTMLWriter.escape(text))</span>"
        }

        private mutating func plain(_ text: String) {
            output += MarkdownHTMLWriter.escape(text)
        }

        private mutating func matchComment() -> String? {
            for marker in rules.lineComments where has(marker, at: index) {
                // `#` only starts a comment where it cannot start a directive.
                if marker == "#", rules.hashWordIsDirective, next(1)?.isLetter == true { continue }
                var end = index
                while end < characters.count, characters[end] != "\n" { end += 1 }
                let text = String(characters[index..<end])
                index = end
                return text
            }
            if let block = rules.blockComment, has(block.open, at: index) {
                var end = index + block.open.count
                while end < characters.count, !has(block.close, at: end) { end += 1 }
                end = min(end + block.close.count, characters.count)
                let text = String(characters[index..<end])
                index = end
                return text
            }
            return nil
        }

        private func stringQuote(at position: Int) -> Character? {
            let character = characters[position]
            return rules.stringQuotes.contains(character) || rules.multilineQuotes.contains(character) ? character : nil
        }

        private mutating func readString(_ quote: Character) -> String {
            let start = index
            let isTriple = rules.tripleQuotes && has(String(repeating: quote, count: 3), at: index)
            let isMultiline = isTriple || rules.multilineQuotes.contains(quote)
            index += isTriple ? 3 : 1
            while index < characters.count {
                let character = characters[index]
                if character == "\\" { index += 2; continue }
                if isTriple {
                    if has(String(repeating: quote, count: 3), at: index) { index += 3; break }
                } else if character == quote {
                    index += 1
                    break
                } else if character == "\n", !isMultiline {
                    break
                }
                index += 1
            }
            index = min(index, characters.count)
            return String(characters[start..<index])
        }

        private mutating func readNumber() -> String {
            let start = index
            index += 1
            while index < characters.count {
                let character = characters[index]
                if character.isLetter || character.isNumber || character == "_" || character == "." {
                    if character == ".", next(1) == "." { break }
                    index += 1
                } else if (character == "+" || character == "-"), "eE".contains(characters[index - 1]), characters[start] != "0" || index - start > 2 {
                    index += 1
                } else {
                    break
                }
            }
            return String(characters[start..<index])
        }

        private mutating func readVariable() -> String {
            let start = index
            index += 1
            if index < characters.count, characters[index] == "{" || characters[index] == "(" {
                let closing: Character = characters[index] == "{" ? "}" : ")"
                while index < characters.count, characters[index] != closing, characters[index] != "\n" { index += 1 }
                index = min(index + 1, characters.count)
            } else {
                while index < characters.count, characters[index].isLetter || characters[index].isNumber || characters[index] == "_" { index += 1 }
            }
            return String(characters[start..<index])
        }

        private mutating func readWord(from position: Int, prefix: String) -> String {
            index = position
            while index < characters.count, characters[index].isLetter || characters[index].isNumber || characters[index] == "_" || characters[index] == "." { index += 1 }
            return prefix + String(characters[position..<index])
        }

        private mutating func readDirective() -> String {
            let start = index
            index += 1
            if index < characters.count, characters[index] == "[" {
                while index < characters.count, characters[index] != "]", characters[index] != "\n" { index += 1 }
                index = min(index + 1, characters.count)
            } else {
                while index < characters.count, characters[index].isLetter || characters[index].isNumber || characters[index] == "_" { index += 1 }
            }
            return String(characters[start..<index])
        }

        private mutating func word() {
            let start = index
            while index < characters.count, characters[index].isLetter || characters[index].isNumber || characters[index] == "_" || characters[index] == "$" { index += 1 }
            let text = String(characters[start..<index])
            let key = rules.isCaseInsensitive ? text.lowercased() : text

            if rules.keywords.contains(key) {
                emit(text, "kw")
            } else if rules.constants.contains(key) {
                emit(text, "num")
            } else {
                var lookahead = index
                while lookahead < characters.count, characters[lookahead] == " " { lookahead += 1 }
                if lookahead < characters.count, characters[lookahead] == "(" {
                    emit(text, "fn")
                } else if rules.capitalisedIsType, text.first?.isUppercase == true, text.contains(where: \.isLowercase) {
                    emit(text, "type")
                } else {
                    plain(text)
                }
            }
        }
    }

    // MARK: Line-oriented languages

    private static func diff(_ code: String) -> String {
        code.split(separator: "\n", omittingEmptySubsequences: false).map { line in
            let escaped = MarkdownHTMLWriter.escape(String(line))
            if line.hasPrefix("+++") || line.hasPrefix("---") || line.hasPrefix("diff ") || line.hasPrefix("index ") {
                return "<span class=\"tok-attr\">\(escaped)</span>"
            }
            if line.hasPrefix("@@") { return "<span class=\"tok-fn\">\(escaped)</span>" }
            if line.hasPrefix("+") { return "<span class=\"tok-add\">\(escaped)</span>" }
            if line.hasPrefix("-") { return "<span class=\"tok-del\">\(escaped)</span>" }
            return escaped
        }.joined(separator: "\n")
    }

    private static func yaml(_ code: String) -> String {
        code.split(separator: "\n", omittingEmptySubsequences: false).map { raw in
            let line = String(raw)
            let indent = line.prefix(while: { $0 == " " })
            var body = String(line.dropFirst(indent.count))
            var output = String(indent)
            if body.hasPrefix("#") {
                return output + "<span class=\"tok-com\">\(MarkdownHTMLWriter.escape(body))</span>"
            }
            if body.hasPrefix("- ") {
                output += "<span class=\"tok-kw\">-</span> "
                body = String(body.dropFirst(2))
            }
            if let match = body.prefixMatch(of: /("[^"]*"|'[^']*'|[A-Za-z0-9_.\/-][^:#]*?):(?=\s|$)/) {
                output += "<span class=\"tok-attr\">\(MarkdownHTMLWriter.escape(String(match.1)))</span>:"
                body = String(body.dropFirst(match.0.count))
            }
            return output + yamlValue(body)
        }.joined(separator: "\n")
    }

    private static func yamlValue(_ text: String) -> String {
        var comment = ""
        var value = text
        if let range = value.range(of: " #") {
            comment = String(value[range.lowerBound...])
            value = String(value[..<range.lowerBound])
        }
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        var rendered = MarkdownHTMLWriter.escape(value)
        if !trimmed.isEmpty {
            let kind: String? =
                if trimmed.hasPrefix("\"") || trimmed.hasPrefix("'") { "str" }
                else if ["true", "false", "null", "yes", "no", "~"].contains(trimmed.lowercased()) { "kw" }
                else if Double(trimmed) != nil { "num" }
                else if trimmed.hasPrefix("&") || trimmed.hasPrefix("*") || trimmed.hasPrefix("!") { "attr" }
                else { nil }
            if let kind {
                rendered = MarkdownHTMLWriter.escape(String(value.prefix(while: { $0 == " " })))
                    + "<span class=\"tok-\(kind)\">\(MarkdownHTMLWriter.escape(trimmed))</span>"
                    + MarkdownHTMLWriter.escape(String(value.reversed().prefix(while: { $0 == " " })))
            }
        }
        return rendered + (comment.isEmpty ? "" : "<span class=\"tok-com\">\(MarkdownHTMLWriter.escape(comment))</span>")
    }

    private static func markup(_ code: String) -> String {
        var output = ""
        var rest = Substring(code)
        while !rest.isEmpty {
            if rest.hasPrefix("<!--") {
                let end = rest.range(of: "-->").map { rest.index($0.upperBound, offsetBy: 0) } ?? rest.endIndex
                output += "<span class=\"tok-com\">\(MarkdownHTMLWriter.escape(String(rest[..<end])))</span>"
                rest = rest[end...]
            } else if let tag = rest.prefixMatch(of: /<\/?[A-Za-z!?][^>]*>?/) {
                output += tagHTML(String(tag.0))
                rest = rest[tag.0.endIndex...]
            } else {
                let end = rest.firstIndex(of: "<").map { $0 == rest.startIndex ? rest.index(after: $0) : $0 } ?? rest.endIndex
                output += MarkdownHTMLWriter.escape(String(rest[..<end]))
                rest = rest[end...]
            }
        }
        return output
    }

    private static func tagHTML(_ tag: String) -> String {
        guard let name = tag.prefixMatch(of: /<\/?[A-Za-z0-9!?:-]+/) else { return MarkdownHTMLWriter.escape(tag) }
        var output = "<span class=\"tok-kw\">\(MarkdownHTMLWriter.escape(String(name.0)))</span>"
        var rest = Substring(tag.dropFirst(name.0.count))
        while !rest.isEmpty {
            if let attribute = rest.prefixMatch(of: /\s+[A-Za-z_:@][A-Za-z0-9_:.@-]*/) {
                let text = String(attribute.0)
                let spaces = text.prefix(while: \.isWhitespace)
                output += String(spaces) + "<span class=\"tok-attr\">\(MarkdownHTMLWriter.escape(String(text.dropFirst(spaces.count))))</span>"
                rest = rest[attribute.0.endIndex...]
            } else if let value = rest.prefixMatch(of: /="[^"]*"|='[^']*'/) {
                output += "=<span class=\"tok-str\">\(MarkdownHTMLWriter.escape(String(value.0.dropFirst())))</span>"
                rest = rest[value.0.endIndex...]
            } else {
                output += MarkdownHTMLWriter.escape(String(rest.first ?? " "))
                rest = rest.dropFirst()
            }
        }
        return output
    }

    private static func css(_ code: String) -> String {
        var output = ""
        var rest = Substring(code)
        var depth = 0
        while !rest.isEmpty {
            if rest.hasPrefix("/*") {
                let end = rest.range(of: "*/").map(\.upperBound) ?? rest.endIndex
                output += "<span class=\"tok-com\">\(MarkdownHTMLWriter.escape(String(rest[..<end])))</span>"
                rest = rest[end...]
            } else if let quoted = rest.prefixMatch(of: /"[^"\n]*"|'[^'\n]*'/) {
                output += "<span class=\"tok-str\">\(MarkdownHTMLWriter.escape(String(quoted.0)))</span>"
                rest = rest[quoted.0.endIndex...]
            } else if depth > 0, let property = rest.prefixMatch(of: /[A-Za-z-]+(?=\s*:)/) {
                output += "<span class=\"tok-attr\">\(MarkdownHTMLWriter.escape(String(property.0)))</span>"
                rest = rest[property.0.endIndex...]
            } else if let number = rest.prefixMatch(of: /#[0-9a-fA-F]{3,8}\b|-?\d+(\.\d+)?(px|em|rem|%|vh|vw|s|ms|deg)?/) {
                output += "<span class=\"tok-num\">\(MarkdownHTMLWriter.escape(String(number.0)))</span>"
                rest = rest[number.0.endIndex...]
            } else if depth == 0, let selector = rest.prefixMatch(of: /[.#@]?[A-Za-z_-][A-Za-z0-9_-]*/) {
                output += "<span class=\"tok-kw\">\(MarkdownHTMLWriter.escape(String(selector.0)))</span>"
                rest = rest[selector.0.endIndex...]
            } else {
                let character = rest.first ?? " "
                if character == "{" { depth += 1 }
                if character == "}" { depth = max(depth - 1, 0) }
                output += MarkdownHTMLWriter.escape(String(character))
                rest = rest.dropFirst()
            }
        }
        return output
    }
}
