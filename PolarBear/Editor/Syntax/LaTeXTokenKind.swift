//
//  LaTeXTokenKind.swift
//  PolarBear
//

/// What a coloured run of source is. TeX uses the first five; Markdown the rest.
enum LaTeXTokenKind {
    case text
    case comment
    case bracket
    case math
    case argument
    case heading
    case code
    case link
    case quote
    case marker
    case emphasis
}
