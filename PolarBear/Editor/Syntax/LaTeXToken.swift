//
//  LaTeXToken.swift
//  PolarBear
//

/// A run of source text with one colour.
struct LaTeXToken {
    /// Length in UTF-16 code units, so it can be used directly in an `NSRange`.
    let length: Int
    let kind: LaTeXTokenKind
}
