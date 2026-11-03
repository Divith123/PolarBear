//
//  LatexMath.swift
//  PolarBear
//

import Foundation

/// Converts the LaTeX maths of a Markdown document (`$…$`, `$$…$$`) to MathML, which WebKit
/// typesets natively, as vector shapes that stay selectable in the PDF. It covers what is used in
/// practice: fractions, roots, scripts and limits, Greek and the usual symbols, accents, delimiters
/// that grow, matrices and aligned equations, text and font styles. A command it does not know is
/// shown in red rather than dropped.
nonisolated struct LatexMath {
    struct Output {
        var markup: String
        /// Commands that could not be converted, so the build can warn about them.
        var unknownCommands: [String]
    }

    static func mathML(_ source: String, display: Bool) -> Output {
        var parser = LatexMath(tokens: tokenize(source), display: display)
        let body = parser.parseTopLevel()
        let attribute = display ? " display=\"block\"" : ""
        // Display style makes sums, products and integrals large and puts their limits above and below.
        let style = "<mstyle displaystyle=\"\(display)\" scriptlevel=\"0\">\(body)</mstyle>"
        return Output(
            markup: "<math xmlns=\"http://www.w3.org/1998/Math/MathML\"\(attribute)>\(style)</math>",
            unknownCommands: parser.unknown
        )
    }

    // MARK: Tokens

    enum Token: Equatable {
        case command(String)
        case character(Character)
        case open, close, caret, underscore, ampersand, rowBreak
    }

    static func tokenize(_ source: String) -> [Token] {
        var tokens: [Token] = []
        let characters = Array(source)
        var index = 0
        while index < characters.count {
            let character = characters[index]
            switch character {
            case "\\":
                index += 1
                guard index < characters.count else { break }
                if characters[index].isLetter {
                    var name = ""
                    while index < characters.count, characters[index].isLetter {
                        name.append(characters[index])
                        index += 1
                    }
                    tokens.append(.command(name))
                    continue
                }
                if characters[index] == "\\" {
                    tokens.append(.rowBreak)
                } else {
                    tokens.append(.command(String(characters[index])))
                }
            case "{": tokens.append(.open)
            case "}": tokens.append(.close)
            case "^": tokens.append(.caret)
            case "_": tokens.append(.underscore)
            case "&": tokens.append(.ampersand)
            case "%":
                while index < characters.count, characters[index] != "\n" { index += 1 }
                continue
            case " ", "\n", "\t": break
            default: tokens.append(.character(character))
            }
            index += 1
        }
        return tokens
    }

    // MARK: Parser state

    var tokens: [Token]
    var position = 0
    let display: Bool
    var unknown: [String] = []

    init(tokens: [Token], display: Bool) {
        self.tokens = tokens
        self.display = display
    }

    var current: Token? { position < tokens.count ? tokens[position] : nil }

    mutating func advance() { position += 1 }

    /// A parsed piece and how scripts attach to it.
    struct Atom {
        enum Limits { case none, byStyle, always }
        var markup: String
        var limits = Limits.none
        /// Marks text that is a single operator symbol (`\not` can strike it through).
        var symbol: String?
    }

    // MARK: Top level

    /// A formula; `\\` and `&` outside any environment make it an aligned table.
    mutating func parseTopLevel() -> String {
        let rows = parseRows(until: { _ in false })
        if rows.count == 1, rows[0].count == 1 { return wrap(rows[0][0]) }
        return table(rows, alignment: "right left", spacing: "0em")
    }

    /// Rows of cells, separated by `\\` and `&`, up to a token that satisfies `stop` (not consumed).
    mutating func parseRows(until stop: (Token) -> Bool) -> [[[String]]] {
        var rows: [[[String]]] = []
        var cells: [[String]] = []
        var cell: [String] = []

        func finishRow() {
            cells.append(cell)
            rows.append(cells)
            cells = []
            cell = []
        }

        while let token = current {
            if stop(token) { break }
            switch token {
            case .ampersand:
                cells.append(cell)
                cell = []
                advance()
            case .rowBreak:
                finishRow()
                advance()
                skipRowSpacing()
            case .close:
                // A stray `}` ends the formula quietly.
                advance()
            default:
                if let atom = parseAtomWithScripts() { cell.append(atom.markup) } else { advance() }
            }
        }
        if !cell.isEmpty || !cells.isEmpty || rows.isEmpty { finishRow() }
        // A trailing `\\` leaves an empty last row.
        if rows.count > 1, rows.last?.count == 1, rows.last?[0].isEmpty == true { rows.removeLast() }
        return rows
    }

    /// `\\[3pt]`: the optional extra space after a row break is dropped.
    mutating func skipRowSpacing() {
        guard current == .character("[") else { return }
        var look = position + 1
        var text = ""
        while look < tokens.count, case .character(let character) = tokens[look], character != "]" {
            text.append(character)
            look += 1
        }
        if look < tokens.count, tokens[look] == .character("]"), text.contains(where: \.isNumber), text.count < 12 {
            position = look + 1
        }
    }

    func wrap(_ items: [String]) -> String {
        items.count == 1 ? items[0] : "<mrow>\(items.joined())</mrow>"
    }

    func table(_ rows: [[[String]]], alignment: String, spacing: String, rowSpacing: String = "0.4em") -> String {
        var markup = "<mtable class=\"\(spacing == "0em" ? "aligned" : "grid")\" displaystyle=\"true\" columnalign=\"\(alignment)\" columnspacing=\"\(spacing)\" rowspacing=\"\(rowSpacing)\">"
        for row in rows {
            markup += "<mtr>" + row.map { "<mtd><mrow>\($0.joined())</mrow></mtd>" }.joined() + "</mtr>"
        }
        return markup + "</mtable>"
    }

    // MARK: Atoms and scripts

    mutating func parseAtomWithScripts() -> Atom? {
        guard var atom = parseAtom() else { return nil }
        var subscriptMarkup: String?
        var superscriptMarkup: String?
        var primes = 0
        if current == .command("limits") {
            atom.limits = .always
            advance()
        } else if current == .command("nolimits") {
            atom.limits = .none
            advance()
        }

        scripts: while let token = current {
            switch token {
            case .caret:
                advance()
                superscriptMarkup = parseScriptArgument()
            case .underscore:
                advance()
                subscriptMarkup = parseScriptArgument()
            case .character("'"):
                advance()
                primes += 1
            default:
                break scripts
            }
        }
        if primes > 0 {
            let marks = "<mo>" + String(repeating: "′", count: primes) + "</mo>"
            superscriptMarkup = superscriptMarkup.map { "<mrow>\(marks)\($0)</mrow>" } ?? marks
        }
        guard subscriptMarkup != nil || superscriptMarkup != nil else { return atom }

        let usesLimits = atom.limits == .always || (atom.limits == .byStyle && display)
        let base = atom.markup
        switch (subscriptMarkup, superscriptMarkup) {
        case (let low?, let high?):
            atom.markup = usesLimits ? "<munderover>\(base)\(low)\(high)</munderover>" : "<msubsup>\(base)\(low)\(high)</msubsup>"
        case (let low?, nil):
            atom.markup = usesLimits ? "<munder>\(base)\(low)</munder>" : "<msub>\(base)\(low)</msub>"
        case (nil, let high?):
            atom.markup = usesLimits ? "<mover>\(base)\(high)</mover>" : "<msup>\(base)\(high)</msup>"
        default:
            break
        }
        atom.limits = .none
        return atom
    }

    /// The argument of `^` or `_`: a group, a command or one character.
    mutating func parseScriptArgument() -> String {
        if current == .open {
            advance()
            return "<mrow>\(parseGroupBody())</mrow>"
        }
        if let atom = parseAtom() { return atom.markup }
        return "<mrow></mrow>"
    }

    /// Everything up to the matching `}` (which is consumed).
    mutating func parseGroupBody() -> String {
        var items: [String] = []
        while let token = current, token != .close {
            if token == .ampersand || token == .rowBreak {
                advance()
                continue
            }
            if let atom = parseAtomWithScripts() { items.append(atom.markup) } else { advance() }
        }
        if current == .close { advance() }
        return items.joined()
    }

    mutating func parseArgument() -> String {
        guard let token = current else { return "<mrow></mrow>" }
        if token == .open {
            advance()
            return "<mrow>\(parseGroupBody())</mrow>"
        }
        return parseAtom()?.markup ?? "<mrow></mrow>"
    }

    /// The raw text of a `{…}` argument (for `\text`, environment names, colours).
    mutating func parseRawArgument() -> String {
        guard current == .open else {
            if case .character(let character)? = current {
                advance()
                return String(character)
            }
            return ""
        }
        advance()
        var depth = 1
        var text = ""
        while let token = current {
            advance()
            switch token {
            case .open: depth += 1; text += "{"
            case .close:
                depth -= 1
                if depth == 0 { return text }
                text += "}"
            case .character(let character): text.append(character)
            case .command(let name): text += name.count == 1 ? name : "\\\(name)"
            case .caret: text += "^"
            case .underscore: text += "_"
            case .ampersand: text += "&"
            case .rowBreak: text += " "
            }
        }
        return text
    }

    mutating func parseAtom() -> Atom? {
        guard let token = current else { return nil }
        switch token {
        case .open:
            advance()
            return Atom(markup: "<mrow>\(parseGroupBody())</mrow>")
        case .close, .caret, .underscore, .ampersand, .rowBreak:
            return nil
        case .character(let character):
            advance()
            return characterAtom(character)
        case .command(let name):
            advance()
            return commandAtom(name)
        }
    }

    mutating func characterAtom(_ character: Character) -> Atom {
        if character.isNumber {
            var digits = String(character)
            while case .character(let next)? = current, next.isNumber || (next == "." && digitFollows()) {
                digits.append(next)
                advance()
            }
            return Atom(markup: "<mn>\(digits)</mn>")
        }
        if character.isLetter { return Atom(markup: "<mi>\(escape(String(character)))</mi>") }
        switch character {
        case "-": return Atom(markup: "<mo>−</mo>", symbol: "−")
        case "*": return Atom(markup: "<mo>∗</mo>")
        case "(", ")", "[", "]": return Atom(markup: "<mo stretchy=\"false\">\(character)</mo>")
        case "~": return Atom(markup: "<mspace width=\"0.33em\"/>")
        case "'": return Atom(markup: "<mo>′</mo>")
        case "|": return Atom(markup: "<mo stretchy=\"false\">|</mo>")
        case ",", ";": return Atom(markup: "<mo separator=\"true\">\(character)</mo>")
        default:
            return Atom(markup: "<mo>\(escape(String(character)))</mo>", symbol: String(character))
        }
    }

    func digitFollows() -> Bool {
        if position + 1 < tokens.count, case .character(let next) = tokens[position + 1] { return next.isNumber }
        return false
    }

    func escape(_ text: String) -> String {
        text.replacing("&", with: "&amp;").replacing("<", with: "&lt;").replacing(">", with: "&gt;")
    }

    mutating func markUnknown(_ name: String) -> Atom {
        unknown.append("\\" + name)
        return Atom(markup: "<mtext mathcolor=\"#cf222e\">\\\(escape(name))</mtext>")
    }
}
