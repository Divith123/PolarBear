//
//  LatexMath+Commands.swift
//  PolarBear
//

import Foundation

/// The backslash commands and environments of the converter.
nonisolated extension LatexMath {
    mutating func commandAtom(_ name: String) -> Atom {
        if let letter = LatexMathSymbols.greek[name] {
            let isUpright = name.first?.isUppercase == true || ["partial", "nabla", "infty", "emptyset", "varnothing", "angle", "top", "bot", "degree", "square", "triangle", "dagger", "ddagger", "S", "P", "copyright", "surd", "Box", "aleph", "beth", "Re", "Im", "wp"].contains(name)
            if name == "prime" { return Atom(markup: "<mo>\(letter)</mo>") }
            return Atom(markup: isUpright ? "<mi mathvariant=\"normal\">\(letter)</mi>" : "<mi>\(letter)</mi>")
        }
        if let symbol = LatexMathSymbols.operators[name] {
            let fence = ["langle", "rangle", "lfloor", "rfloor", "lceil", "rceil", "lbrace", "rbrace", "lbrack", "rbrack", "vert", "Vert", "|", "lvert", "rvert", "lVert", "rVert", "{", "}"].contains(name)
            return Atom(markup: fence ? "<mo stretchy=\"false\">\(escape(symbol))</mo>" : "<mo>\(escape(symbol))</mo>", symbol: symbol)
        }
        if let symbol = LatexMathSymbols.largeOperators[name] {
            // WebKit does not pick the larger glyph of a sum or product by itself, so display style sets the size.
            let size = display ? " mathsize=\"1.6em\" stretchy=\"false\"" : ""
            return Atom(markup: "<mo largeop=\"true\" movablelimits=\"false\"\(size)>\(symbol)</mo>", limits: .byStyle)
        }
        if let symbol = LatexMathSymbols.integrals[name] {
            return Atom(markup: "<mo largeop=\"true\" movablelimits=\"false\">\(symbol)</mo>")
        }
        if LatexMathSymbols.limitOperators.contains(name) {
            return Atom(markup: "<mi mathvariant=\"normal\">\(name)</mi>", limits: .byStyle)
        }
        if LatexMathSymbols.namedOperators.contains(name) {
            return Atom(markup: "<mi mathvariant=\"normal\" style=\"margin-right:0.17em\">\(name)</mi>")
        }
        if let accent = LatexMathSymbols.accents[name] {
            let isBrace = name == "overbrace"
            let base = parseArgument()
            let over = "<mover accent=\"\(isBrace ? "false" : "true")\">\(base)<mo stretchy=\"true\">\(accent)</mo></mover>"
            return Atom(markup: over, limits: isBrace ? .always : .none)
        }
        if let accent = LatexMathSymbols.underAccents[name] {
            let base = parseArgument()
            let isBrace = name == "underbrace"
            return Atom(markup: "<munder accentunder=\"\(isBrace ? "false" : "true")\">\(base)<mo stretchy=\"true\">\(accent)</mo></munder>", limits: isBrace ? .always : .none)
        }

        switch name {
        case "frac", "cfrac", "dfrac", "tfrac":
            let numerator = parseArgument(), denominator = parseArgument()
            let fraction = "<mfrac>\(numerator)\(denominator)</mfrac>"
            if name == "dfrac" || name == "cfrac" { return Atom(markup: "<mstyle displaystyle=\"true\">\(fraction)</mstyle>") }
            if name == "tfrac" { return Atom(markup: "<mstyle displaystyle=\"false\">\(fraction)</mstyle>") }
            return Atom(markup: fraction)
        case "binom", "dbinom", "tbinom":
            let top = parseArgument(), bottom = parseArgument()
            return Atom(markup: "<mrow><mo>(</mo><mfrac linethickness=\"0\">\(top)\(bottom)</mfrac><mo>)</mo></mrow>")
        case "sqrt":
            var index: String?
            if current == .character("[") {
                advance()
                var items: [String] = []
                while let token = current, token != .character("]") {
                    if let atom = parseAtomWithScripts() { items.append(atom.markup) } else { advance() }
                    _ = token
                }
                if current == .character("]") { advance() }
                index = "<mrow>\(items.joined())</mrow>"
            }
            let radicand = parseArgument()
            return Atom(markup: index.map { "<mroot>\(radicand)\($0)</mroot>" } ?? "<msqrt>\(radicand)</msqrt>")
        case "text", "textrm", "mbox", "hbox", "textnormal":
            return Atom(markup: "<mtext>\(escape(parseRawArgument()).replacing(" ", with: "&#x00A0;"))</mtext>")
        case "textbf": return Atom(markup: "<mtext mathvariant=\"bold\">\(escape(parseRawArgument()).replacing(" ", with: "&#x00A0;"))</mtext>")
        case "textit", "emph": return Atom(markup: "<mtext mathvariant=\"italic\">\(escape(parseRawArgument()).replacing(" ", with: "&#x00A0;"))</mtext>")
        case "mathrm", "operatorname*", "mathnormal": return styled("normal")
        case "mathbf", "boldsymbol", "bm", "pmb", "mathbfit": return styled("bold")
        case "mathit": return styled("italic")
        case "mathsf": return styled("sans-serif")
        case "mathtt": return styled("monospace")
        case "mathbb", "mathcal", "mathscr", "mathfrak":
            let text = parseRawArgument()
            return Atom(markup: "<mi mathvariant=\"normal\">\(escape(LatexMathSymbols.styled(text, style: name)))</mi>")
        case "operatorname", "mathop":
            let text = parseRawArgument()
            return Atom(markup: "<mi mathvariant=\"normal\" style=\"margin-right:0.17em\">\(escape(text))</mi>", limits: LatexMathSymbols.limitOperators.contains(text) ? .byStyle : .none)
        case "color":
            let colour = cssColour(parseRawArgument())
            var items: [String] = []
            while let token = current, token != .close, token != .ampersand, token != .rowBreak {
                if let atom = parseAtomWithScripts() { items.append(atom.markup) } else { advance() }
            }
            return Atom(markup: "<mstyle mathcolor=\"\(colour)\">\(items.joined())</mstyle>")
        case "textcolor":
            let colour = cssColour(parseRawArgument())
            return Atom(markup: "<mstyle mathcolor=\"\(colour)\">\(parseArgument())</mstyle>")
        case "boxed":
            return Atom(markup: "<mrow style=\"border:1px solid currentColor;padding:0.2em 0.35em\">\(parseArgument())</mrow>")
        case "cancel", "bcancel", "xcancel", "sout":
            return Atom(markup: "<mrow style=\"text-decoration:line-through\">\(parseArgument())</mrow>")
        case "phantom", "hphantom", "vphantom":
            return Atom(markup: "<mphantom>\(parseArgument())</mphantom>")
        case "stackrel", "overset":
            let above = parseArgument(), base = parseArgument()
            return Atom(markup: "<mover>\(base)\(above)</mover>")
        case "underset":
            let below = parseArgument(), base = parseArgument()
            return Atom(markup: "<munder>\(base)\(below)</munder>")
        case "xrightarrow", "xleftarrow", "xRightarrow", "xLeftarrow", "xleftrightarrow":
            let arrow = ["xrightarrow": "→", "xleftarrow": "←", "xRightarrow": "⇒", "xLeftarrow": "⇐", "xleftrightarrow": "↔"][name] ?? "→"
            var below: String?
            if current == .character("[") {
                advance()
                var items: [String] = []
                while let token = current, token != .character("]") {
                    if let atom = parseAtomWithScripts() { items.append(atom.markup) } else { advance() }
                    _ = token
                }
                if current == .character("]") { advance() }
                below = "<mrow>\(items.joined())</mrow>"
            }
            let above = parseArgument()
            let arrowMarkup = "<mo stretchy=\"true\" minsize=\"2.2em\">\(arrow)</mo>"
            return Atom(markup: below.map { "<munderover>\(arrowMarkup)\($0)\(above)</munderover>" } ?? "<mover>\(arrowMarkup)\(above)</mover>")
        case "not":
            if let next = parseAtom() {
                if let symbol = next.symbol { return Atom(markup: "<mo>\(escape(symbol))\u{0338}</mo>") }
                return Atom(markup: "<mrow>\(next.markup)<mo≯</mo></mrow>")
            }
            return Atom(markup: "")
        case "left":
            return fenced()
        case "right", "middle":
            let delimiter = readDelimiter()
            return Atom(markup: delimiter.isEmpty ? "" : "<mo fence=\"true\" stretchy=\"true\">\(escape(delimiter))</mo>")
        case "big", "bigl", "bigr", "bigm", "Big", "Bigl", "Bigr", "Bigm", "bigg", "biggl", "biggr", "biggm", "Bigg", "Biggl", "Biggr", "Biggm":
            let size = name.hasPrefix("Bigg") || name.hasPrefix("bigg") ? (name.hasPrefix("B") ? "3em" : "2.4em") : (name.hasPrefix("B") ? "1.8em" : "1.2em")
            let delimiter = readDelimiter()
            return Atom(markup: delimiter.isEmpty ? "" : "<mo fence=\"true\" stretchy=\"true\" symmetric=\"true\" minsize=\"\(size)\" maxsize=\"\(size)\">\(escape(delimiter))</mo>")
        case "begin":
            return environment()
        case "end":
            _ = parseRawArgument()
            return Atom(markup: "")
        case ",": return space("0.1667em")
        case ":", ">": return space("0.2222em")
        case ";": return space("0.2778em")
        case "!": return space("-0.1667em")
        case " ", "enspace": return space("0.3333em")
        case "quad": return space("1em")
        case "qquad": return space("2em")
        case "hspace", "hspace*", "mspace", "kern", "mkern":
            let length = parseRawArgument().trimmingCharacters(in: .whitespaces)
            let converted = length.replacing("mu", with: "em")
            return Atom(markup: converted.isEmpty ? "" : "<mspace width=\"\(escape(converted))\"/>")
        case "displaystyle", "textstyle", "scriptstyle", "scriptscriptstyle", "relax", "nonumber", "notag", "hline", "limits", "nolimits", "mathstrut", "strut", "allowbreak", "protect", "bigskip", "medskip", "smallskip", "vspace", "vspace*", "newline", "centering":
            if name.hasPrefix("vspace") { _ = parseRawArgument() }
            return Atom(markup: "")
        case "tag", "tag*", "label", "ref", "eqref", "cite", "href", "url":
            let text = parseRawArgument()
            return Atom(markup: name.hasPrefix("tag") ? "<mspace width=\"2em\"/><mtext>(\(escape(text)))</mtext>" : "")
        case "%", "$", "#", "&", "_": return Atom(markup: "<mo>\(name)</mo>")
        case "-": return Atom(markup: "")
        case "/": return Atom(markup: "<mo>/</mo>")
        case "'", "`", "\"", "^", "~", "=", ".": return Atom(markup: "<mo>\(escape(name))</mo>")
        default:
            return markUnknown(name)
        }
    }

    // MARK: Pieces

    private mutating func styled(_ variant: String) -> Atom {
        Atom(markup: "<mstyle mathvariant=\"\(variant)\">\(parseArgument())</mstyle>")
    }

    private func space(_ width: String) -> Atom {
        Atom(markup: "<mspace width=\"\(width)\"/>")
    }

    private func cssColour(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if let known = LatexMathSymbols.colours[trimmed.lowercased()] { return known }
        if trimmed.hasPrefix("#") { return trimmed }
        if trimmed.count == 6, trimmed.allSatisfy(\.isHexDigit) { return "#" + trimmed }
        return "currentColor"
    }

    /// The delimiter after `\left`, `\right` or `\big`: a character or a command; `.` means none.
    private mutating func readDelimiter() -> String {
        guard let token = current else { return "" }
        advance()
        switch token {
        case .character(let character): return character == "." ? "" : String(character)
        case .command(let name):
            if let symbol = LatexMathSymbols.operators[name] { return symbol }
            if name == "|" { return "‖" }
            return ""
        case .open: return "{"
        case .close: return "}"
        default: return ""
        }
    }

    /// `\left( … \right)`.
    private mutating func fenced() -> Atom {
        let opening = readDelimiter()
        var items: [String] = []
        while let token = current, token != .command("right") {
            if token == .close { break }
            if token == .ampersand || token == .rowBreak {
                advance()
                continue
            }
            if let atom = parseAtomWithScripts() { items.append(atom.markup) } else { advance() }
        }
        var closing = ""
        if current == .command("right") {
            advance()
            closing = readDelimiter()
        }
        var markup = "<mrow>"
        if !opening.isEmpty { markup += "<mo fence=\"true\" stretchy=\"true\" form=\"prefix\">\(escape(opening))</mo>" }
        markup += items.joined()
        if !closing.isEmpty { markup += "<mo fence=\"true\" stretchy=\"true\" form=\"postfix\">\(escape(closing))</mo>" }
        return Atom(markup: markup + "</mrow>")
    }

    // MARK: Environments

    private mutating func environment() -> Atom {
        let name = parseRawArgument().trimmingCharacters(in: .whitespaces)
        var columnSpec = ""
        if name == "array" || name == "subarray" { columnSpec = parseRawArgument() }

        let rows = parseRows(until: { $0 == .command("end") })
        if current == .command("end") {
            advance()
            _ = parseRawArgument()
        }

        func matrix(open: String, close: String) -> Atom {
            let body = table(rows, alignment: "center", spacing: "1em")
            let fences = open.isEmpty ? body : "<mrow><mo fence=\"true\" stretchy=\"true\">\(open)</mo>\(body)<mo fence=\"true\" stretchy=\"true\">\(close)</mo></mrow>"
            return Atom(markup: fences)
        }

        switch name.replacing("*", with: "") {
        case "matrix", "smallmatrix": return matrix(open: "", close: "")
        case "pmatrix": return matrix(open: "(", close: ")")
        case "bmatrix": return matrix(open: "[", close: "]")
        case "Bmatrix": return matrix(open: "{", close: "}")
        case "vmatrix": return matrix(open: "|", close: "|")
        case "Vmatrix": return matrix(open: "‖", close: "‖")
        case "cases", "dcases":
            let body = table(rows, alignment: "left left", spacing: "1em")
            return Atom(markup: "<mrow><mo fence=\"true\" stretchy=\"true\">{</mo>\(body)</mrow>")
        case "array", "subarray":
            let letters = columnSpec.filter { "lcr".contains($0) }.map { $0 == "l" ? "left" : ($0 == "r" ? "right" : "center") }
            return Atom(markup: table(rows, alignment: letters.isEmpty ? "center" : letters.joined(separator: " "), spacing: "1em"))
        case "aligned", "align", "alignat", "split", "eqnarray", "flalign":
            return Atom(markup: table(rows, alignment: "right left", spacing: "0em"))
        case "gather", "gathered", "multline":
            return Atom(markup: table(rows, alignment: "center", spacing: "0em"))
        case "equation", "displaymath", "math", "eqnarray*", "darray":
            return Atom(markup: rows.count == 1 && rows[0].count == 1 ? wrap(rows[0][0]) : table(rows, alignment: "center", spacing: "0em"))
        default:
            unknown.append("\\begin{\(name)}")
            return Atom(markup: table(rows, alignment: "center", spacing: "1em"))
        }
    }
}
