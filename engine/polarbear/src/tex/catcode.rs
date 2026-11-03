// Copyright (c) 2026 Divith123. Licensed under the MIT License.

//! Character category codes — layer 0 of the TeX input processor.
//!
//! Every character carries one of sixteen category codes; the codes decide
//! how the scanner treats it, and `\catcode` reassignments live in the
//! per-engine [`CatCodeTable`].

use std::fmt;

/// The sixteen TeX category codes a character can carry.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum CategoryCode {
    /// Catcode 0: introduces a control sequence (`\`).
    Escape,
    /// Catcode 1: begins a group (`{`).
    BeginGroup,
    /// Catcode 2: ends a group (`}`).
    EndGroup,
    /// Catcode 3: math shift (`$`).
    MathShift,
    /// Catcode 4: alignment tab (`&`).
    AlignmentTab,
    /// Catcode 5: end-of-line character.
    EndOfLine,
    /// Catcode 6: macro parameter character (`#`).
    Parameter,
    /// Catcode 7: superscript (`^`); two identical ones also start `^^`
    /// notation.
    Superscript,
    /// Catcode 8: subscript (`_`).
    Subscript,
    /// Catcode 9: ignored.
    Ignored,
    /// Catcode 10: space.
    Space,
    /// Catcode 11: letter (only letters form multi-letter control words).
    Letter,
    /// Catcode 12: other (the default).
    Other,
    /// Catcode 13: active character (acts like a one-letter control
    /// sequence).
    Active,
    /// Catcode 14: comment character (rest of the line is discarded).
    Comment,
    /// Catcode 15: invalid character.
    Invalid,
}

impl CategoryCode {
    /// The numeric catcode, as written in `\catcode` assignments.
    #[must_use]
    pub const fn as_number(self) -> u8 {
        match self {
            Self::Escape => 0,
            Self::BeginGroup => 1,
            Self::EndGroup => 2,
            Self::MathShift => 3,
            Self::AlignmentTab => 4,
            Self::EndOfLine => 5,
            Self::Parameter => 6,
            Self::Superscript => 7,
            Self::Subscript => 8,
            Self::Ignored => 9,
            Self::Space => 10,
            Self::Letter => 11,
            Self::Other => 12,
            Self::Active => 13,
            Self::Comment => 14,
            Self::Invalid => 15,
        }
    }
}

impl fmt::Display for CategoryCode {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        write!(f, "{}", self.as_number())
    }
}

/// The catcode a character gets at engine initialization: TeX's INITEX
/// defaults, extended to all of Unicode by treating alphabetic characters
/// as letters.
///
/// # Approximations (tuned against the reference oracle in a later
/// milestone)
///
/// Unicode membership is `char::is_alphabetic`, which is close to but not
/// provably identical to the engines' Unicode letter tables; XeTeX's
/// CJK/active ranges are also not assigned yet.
#[must_use]
pub fn default_catcode(c: char) -> CategoryCode {
    match c {
        '\\' => CategoryCode::Escape,
        '{' => CategoryCode::BeginGroup,
        '}' => CategoryCode::EndGroup,
        '$' => CategoryCode::MathShift,
        '&' => CategoryCode::AlignmentTab,
        '%' => CategoryCode::Comment,
        '~' => CategoryCode::Active,
        '\r' => CategoryCode::EndOfLine,
        '#' => CategoryCode::Parameter,
        '^' => CategoryCode::Superscript,
        '_' => CategoryCode::Subscript,
        ' ' => CategoryCode::Space,
        '\u{0}' | '\u{7F}' => CategoryCode::Invalid,
        c if c.is_alphabetic() => CategoryCode::Letter,
        _ => CategoryCode::Other,
    }
}

/// The per-engine catcode table, mutable exactly the way `\catcode`
/// assignments make it.
pub struct CatCodeTable {
    codes: Vec<CategoryCode>,
}

impl CatCodeTable {
    /// A table holding the default catcode of every Unicode codepoint
    /// (about 1.1 MB; one engine instance owns one table).
    #[must_use]
    pub fn with_defaults() -> Self {
        let mut codes = vec![CategoryCode::Other; char::MAX as usize + 1];
        for (index, code) in codes.iter_mut().enumerate() {
            if let Some(c) = char::from_u32(index as u32) {
                *code = default_catcode(c);
            }
        }
        Self { codes }
    }

    /// Look up the current catcode of `c`.
    #[must_use]
    pub fn get(&self, c: char) -> CategoryCode {
        self.codes[c as usize]
    }

    /// Assign a catcode, as `\catcode` does.
    pub fn set(&mut self, c: char, code: CategoryCode) {
        self.codes[c as usize] = code;
    }
}
