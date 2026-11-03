//
//  LatexMathSymbols.swift
//  PolarBear
//

import Foundation

/// The symbol tables of the LaTeX-to-MathML converter.
nonisolated enum LatexMathSymbols {
    /// Letters of the Greek alphabet: lower case is slanted, upper case upright.
    static let greek: [String: String] = [
        "alpha": "α", "beta": "β", "gamma": "γ", "delta": "δ", "epsilon": "ϵ", "varepsilon": "ε", "zeta": "ζ",
        "eta": "η", "theta": "θ", "vartheta": "ϑ", "iota": "ι", "kappa": "κ", "lambda": "λ", "mu": "μ", "nu": "ν",
        "xi": "ξ", "pi": "π", "varpi": "ϖ", "rho": "ρ", "varrho": "ϱ", "sigma": "σ", "varsigma": "ς", "tau": "τ",
        "upsilon": "υ", "phi": "ϕ", "varphi": "φ", "chi": "χ", "psi": "ψ", "omega": "ω",
        "Gamma": "Γ", "Delta": "Δ", "Theta": "Θ", "Lambda": "Λ", "Xi": "Ξ", "Pi": "Π", "Sigma": "Σ",
        "Upsilon": "Υ", "Phi": "Φ", "Psi": "Ψ", "Omega": "Ω",
        "ell": "ℓ", "hbar": "ℏ", "imath": "ı", "jmath": "ȷ", "aleph": "ℵ", "beth": "ℶ", "wp": "℘",
        "Re": "ℜ", "Im": "ℑ", "partial": "∂", "nabla": "∇", "infty": "∞", "emptyset": "∅", "varnothing": "∅",
        "angle": "∠", "top": "⊤", "bot": "⊥", "degree": "°", "prime": "′", "square": "□", "triangle": "△",
        "dagger": "†", "ddagger": "‡", "S": "§", "P": "¶", "copyright": "©", "surd": "√", "Box": "□",
    ]

    /// Symbols that are operators or relations.
    static let operators: [String: String] = [
        "pm": "±", "mp": "∓", "times": "×", "div": "÷", "cdot": "⋅", "ast": "∗", "star": "⋆", "circ": "∘",
        "bullet": "∙", "oplus": "⊕", "ominus": "⊖", "otimes": "⊗", "oslash": "⊘", "odot": "⊙", "cup": "∪",
        "cap": "∩", "setminus": "∖", "backslash": "∖", "wedge": "∧", "land": "∧", "vee": "∨", "lor": "∨",
        "neg": "¬", "lnot": "¬", "leq": "≤", "le": "≤", "geq": "≥", "ge": "≥", "neq": "≠", "ne": "≠",
        "approx": "≈", "equiv": "≡", "sim": "∼", "simeq": "≃", "cong": "≅", "propto": "∝", "ll": "≪", "gg": "≫",
        "subset": "⊂", "supset": "⊃", "subseteq": "⊆", "supseteq": "⊇", "sqsubset": "⊏", "sqsupset": "⊐",
        "in": "∈", "notin": "∉", "ni": "∋", "forall": "∀", "exists": "∃", "nexists": "∄", "perp": "⊥",
        "parallel": "∥", "mid": "∣", "nmid": "∤", "to": "→", "rightarrow": "→", "leftarrow": "←", "gets": "←",
        "leftrightarrow": "↔", "Rightarrow": "⇒", "Leftarrow": "⇐", "Leftrightarrow": "⇔", "iff": "⟺",
        "implies": "⟹", "impliedby": "⟸", "mapsto": "↦", "uparrow": "↑", "downarrow": "↓", "updownarrow": "↕",
        "Uparrow": "⇑", "Downarrow": "⇓", "longrightarrow": "⟶", "longleftarrow": "⟵", "longleftrightarrow": "⟷",
        "Longrightarrow": "⟹", "Longleftarrow": "⟸", "hookrightarrow": "↪", "hookleftarrow": "↩",
        "rightleftharpoons": "⇌", "nearrow": "↗", "searrow": "↘", "swarrow": "↙", "nwarrow": "↖",
        "ldots": "…", "dots": "…", "cdots": "⋯", "vdots": "⋮", "ddots": "⋱", "vdash": "⊢", "models": "⊨",
        "dashv": "⊣", "therefore": "∴", "because": "∵", "asymp": "≍", "doteq": "≐", "succ": "≻", "prec": "≺",
        "succeq": "⪰", "preceq": "⪯", "bigstar": "★", "diamond": "⋄", "triangleleft": "◁", "triangleright": "▷",
        "wr": "≀", "amalg": "⨿", "uplus": "⊎", "sqcup": "⊔", "sqcap": "⊓", "lessim": "≲", "gtrsim": "≳",
        "colon": ":", "langle": "⟨", "rangle": "⟩", "lfloor": "⌊", "rfloor": "⌋", "lceil": "⌈", "rceil": "⌉",
        "lbrace": "{", "rbrace": "}", "lbrack": "[", "rbrack": "]", "vert": "|", "Vert": "‖", "|": "‖",
        "lvert": "|", "rvert": "|", "lVert": "‖", "rVert": "‖", "{": "{", "}": "}",
    ]

    /// Operators that take their limits above and below in display style.
    static let largeOperators: [String: String] = [
        "sum": "∑", "prod": "∏", "coprod": "∐", "bigcup": "⋃", "bigcap": "⋂", "bigvee": "⋁", "bigwedge": "⋀",
        "bigoplus": "⨁", "bigotimes": "⨂", "bigodot": "⨀", "biguplus": "⨄", "bigsqcup": "⨆",
    ]

    /// Integrals keep their limits at the side.
    static let integrals: [String: String] = ["int": "∫", "iint": "∬", "iiint": "∭", "oint": "∮", "oiint": "∯"]

    /// Named operators set upright; the first group takes limits.
    static let limitOperators: Set<String> = ["lim", "limsup", "liminf", "max", "min", "sup", "inf", "det", "gcd", "Pr", "argmax", "argmin"]
    static let namedOperators: Set<String> = [
        "sin", "cos", "tan", "cot", "sec", "csc", "arcsin", "arccos", "arctan", "sinh", "cosh", "tanh", "coth",
        "log", "ln", "lg", "exp", "deg", "dim", "ker", "hom", "arg", "Re", "Im", "mod", "bmod", "pmod", "sgn", "tr",
        "rank", "span", "id", "lcm",
    ]

    /// `\accent{x}` → the combining character drawn over it.
    static let accents: [String: String] = [
        "hat": "^", "widehat": "^", "tilde": "~", "widetilde": "~", "bar": "¯", "overline": "¯", "vec": "→",
        "overrightarrow": "→", "overleftarrow": "←", "dot": "˙", "ddot": "¨", "dddot": "⃛", "acute": "´", "grave": "`",
        "breve": "˘", "check": "ˇ", "mathring": "˚", "overbrace": "⏞",
    ]

    static let underAccents: [String: String] = ["underline": "_", "underbrace": "⏟", "underleftarrow": "←", "underrightarrow": "→"]

    /// `\mathbb{R}` and friends: the Unicode block of each style.
    static func styled(_ text: String, style: String) -> String {
        func map(_ upper: UInt32, _ lower: UInt32?, _ digit: UInt32?, exceptions: [Character: String] = [:]) -> String {
            String(text.map { character -> String in
                if let special = exceptions[character] { return special }
                guard let value = character.unicodeScalars.first?.value else { return String(character) }
                if (65...90).contains(value) { return String(Character(Unicode.Scalar(upper + value - 65)!)) }
                if let lower, (97...122).contains(value) { return String(Character(Unicode.Scalar(lower + value - 97)!)) }
                if let digit, (48...57).contains(value) { return String(Character(Unicode.Scalar(digit + value - 48)!)) }
                return String(character)
            }.joined())
        }
        switch style {
        case "mathbb": return map(0x1D538, 0x1D552, 0x1D7D8, exceptions: ["C": "ℂ", "H": "ℍ", "N": "ℕ", "P": "ℙ", "Q": "ℚ", "R": "ℝ", "Z": "ℤ"])
        case "mathcal", "mathscr": return map(0x1D49C, 0x1D4B6, nil, exceptions: ["B": "ℬ", "E": "ℰ", "F": "ℱ", "H": "ℋ", "I": "ℐ", "L": "ℒ", "M": "ℳ", "R": "ℛ", "e": "ℯ", "g": "ℊ", "o": "ℴ"])
        case "mathfrak": return map(0x1D504, 0x1D51E, nil, exceptions: ["C": "ℭ", "H": "ℌ", "I": "ℑ", "R": "ℜ", "Z": "ℨ"])
        default: return text
        }
    }

    static let colours: [String: String] = [
        "red": "#cf222e", "blue": "#0969da", "green": "#1a7f37", "black": "#000000", "gray": "#6e7781",
        "grey": "#6e7781", "orange": "#bc4c00", "purple": "#8250df", "cyan": "#0598bc", "magenta": "#bf3989",
        "yellow": "#9a6700", "brown": "#7d4e21", "teal": "#0a7f7f", "pink": "#bf3989",
    ]
}
