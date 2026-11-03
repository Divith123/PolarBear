// Copyright (c) 2026 Divith123. Licensed under the MIT License.

//! Tokens — layer 1: catcoded characters and control sequences, the units
//! the scanner hands to expansion.

use std::fmt;

use super::catcode::CategoryCode;

/// How a control sequence was formed (TeX keeps the distinction; it shapes
/// `\show`-style output and name matching for active characters).
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum CsKind {
    /// A multi-letter control word (`\foo`).
    ControlWord,
    /// A single-character control symbol (`\ `, `\%`, `\{`, …).
    ControlSymbol,
    /// An active character used as a control sequence (`~`); the sequence
    /// is named by its character.
    Active,
}

/// A control sequence as a token: its name plus how it was formed.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct ControlSequence {
    /// The sequence text without the escape character (`foo` for `\foo`).
    pub name: String,
    /// How the sequence was formed.
    pub kind: CsKind,
}

/// One token of the TeX input stream.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum Token {
    /// A control sequence (including active characters).
    Cs(ControlSequence),
    /// A character with its (current) catcode. Category codes 9 and 15
    /// never reach this point — the scanner drops them.
    Char(char, CategoryCode),
    /// A macro-parameter placeholder (`#1`…`#9`), 0-based. Produced only
    /// by `\def`-family scans inside the expansion processor; raw input
    /// never yields one.
    Parameter(u8),
    /// A group-open marker: `{` reached the main processing. The
    /// expander keeps its own undo log; the marker lets the main
    /// processor open the right container (box bodies, nested braces).
    GroupBegin,
    /// A group-close marker: `}` reached the main processing.
    GroupEnd,
}

impl fmt::Display for Token {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        match self {
            Token::Cs(cs) => write!(f, "\\{}", cs.name),
            Token::Char(c, _) => write!(f, "{c}"),
            Token::GroupBegin => write!(f, "{{"),
            Token::GroupEnd => write!(f, "}}"),
            Token::Parameter(n) => write!(f, "#{}", n + 1),
        }
    }
}
