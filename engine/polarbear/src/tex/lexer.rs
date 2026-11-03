// Copyright (c) 2026 Divith123. Licensed under the MIT License.

//! The input scanner — layer 2: lines into tokens.
//!
//! Implements the classic line/character rules (TeXbook ch. 8):
//!
//! * trailing catcode-10 characters are stripped from every input line;
//! * `^^` notation pairs (char±64 and hex) are resolved to single
//!   characters, using the charcode-based hex-digit test; the produced
//!   character is never re-examined for another pair, and it goes through
//!   the full state machine afterwards (a produced `%` comments, a
//!   produced `\` escapes);
//! * an empty line — or one holding only spaces — collapses to `\par`;
//! * a comment character discards the rest of its line, including the
//!   endline character, so comments join lines without adding a space;
//! * a non-blank line ends in the endline character, which behaves as a
//!   space in mid-line state and vanishes at the start of a line (this is
//!   why consecutive source lines never accidentally concatenate).
//!
//! # State model
//!
//! TeX's three input states collapse observationally into two: states N
//! (new line) and S (skipping blanks) agree on every input character, so
//! the scanner tracks [`State::Mid`] vs [`State::Quiet`].

use std::collections::VecDeque;

use super::{
    catcode::{CatCodeTable, CategoryCode},
    token::{ControlSequence, CsKind, Token},
};

/// The line-scanner state, reduced to its two observationally distinct
/// classes.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum State {
    /// A character just extended a token run (mid line).
    Mid,
    /// Nothing is pending; spaces and endline characters produce nothing.
    Quiet,
}

/// The character appended to every non-blank input line before tokenizing.
///
/// TODO(engine-milestone L2): becomes an engine parameter (`\endlinechar`).
const ENDLINE_CHAR: char = '\r';

/// One physical line, preprocessed: resolved characters plus a parallel
/// flag marking characters that came out of `^^` notation (those never
/// start a second pair).
struct PreparedLine {
    chars: Vec<char>,
    from_notation: Vec<bool>,
}

/// Tokenizes TeX source text through the engine's catcode table — the
/// first stage of every compile.
pub struct Lexer<'a> {
    cat: CatCodeTable,
    lines: std::str::Lines<'a>,
    state: State,
    queued: VecDeque<Token>,
}

impl<'a> Lexer<'a> {
    /// A lexer for `source`, splitting on newlines and tokenizing with
    /// default catcodes.
    #[must_use]
    pub fn new(source: &'a str) -> Self {
        Self::with_catcodes(source, CatCodeTable::with_defaults())
    }

    /// A lexer for `source`, tokenizing with an existing catcode table.
    #[must_use]
    pub fn with_catcodes(source: &'a str, cat: CatCodeTable) -> Self {
        Self {
            cat,
            lines: source.lines(),
            state: State::Quiet,
            queued: VecDeque::new(),
        }
    }

    /// The next token, or `None` at end of input.
    pub fn next_token(&mut self) -> Option<Token> {
        loop {
            if let Some(token) = self.queued.pop_front() {
                return Some(token);
            }
            let line = self.lines.next()?;
            self.queue_line(line);
        }
    }

    /// Tokenize one physical line into `queued`.
    ///
    /// Order of operations: `^^` resolution, trailing-space strip, the
    /// blank-line rule, then the state-machine scan over the line plus its
    /// appended endline character. State resets at every line start; the
    /// appended endline char can never pair into a notation (it is not
    /// catcode 7 by default).
    fn queue_line(&mut self, raw: &str) {
        self.state = State::Quiet;

        let raw_chars: Vec<char> = raw.chars().collect();
        let mut prepared = self.resolve_notations(&raw_chars);

        while prepared
            .chars
            .last()
            .is_some_and(|&c| self.cat.get(c) == CategoryCode::Space)
        {
            prepared.chars.pop();
            prepared.from_notation.pop();
        }

        if prepared.chars.is_empty() {
            // A blank line ends the paragraph, whatever the pending state.
            self.queue_cs(String::from("par"), CsKind::ControlWord, State::Quiet);
            return;
        }

        prepared.chars.push(ENDLINE_CHAR);
        prepared.from_notation.push(false);

        let mut idx = 0;
        while idx < prepared.chars.len() {
            let c = prepared.chars[idx];

            match self.cat.get(c) {
                CategoryCode::Escape => match self.scan_control_sequence(&prepared.chars, idx) {
                    Some(consumed) => idx += consumed,
                    // Only possible if the endline char itself lost its
                    // catcode; handled as an engine error in a later
                    // milestone.
                    None => break,
                },
                CategoryCode::Comment => {
                    // Rest of the line — including the appended endline
                    // char — is discarded: comments join lines.
                    break;
                }
                CategoryCode::Space => {
                    if self.state == State::Mid {
                        self.queued.push_back(Token::Char(c, CategoryCode::Space));
                    }
                    self.state = State::Quiet;
                    idx += 1;
                }
                CategoryCode::EndOfLine => {
                    // Mid line the endline becomes a space token; at a
                    // line start (Quiet) it vanishes.
                    if self.state == State::Mid {
                        self.queued.push_back(Token::Char(' ', CategoryCode::Space));
                    }
                    self.state = State::Quiet;
                    idx += 1;
                }
                CategoryCode::Ignored | CategoryCode::Invalid => {
                    idx += 1;
                }
                CategoryCode::Active => {
                    self.queue_cs(c.to_string(), CsKind::Active, State::Mid);
                    idx += 1;
                }
                _ => {
                    self.queued.push_back(Token::Char(c, self.cat.get(c)));
                    self.state = State::Mid;
                    idx += 1;
                }
            }
        }
    }

    /// Resolve every `^^` notation pair of `chars` to its produced
    /// character, left to right on the raw characters. No recursion: a
    /// produced character is never re-examined for another pair.
    fn resolve_notations(&self, chars: &[char]) -> PreparedLine {
        let mut out = PreparedLine {
            chars: Vec::with_capacity(chars.len()),
            from_notation: Vec::with_capacity(chars.len()),
        };

        let mut idx = 0;
        while idx < chars.len() {
            let c = chars[idx];
            let pair_head = self.cat.get(c) == CategoryCode::Superscript
                && chars.get(idx + 1) == Some(&c);
            if !pair_head {
                out.chars.push(c);
                out.from_notation.push(false);
                idx += 1;
                continue;
            }

            // Hex form: the two characters after `^^` are hex digits by
            // character code (TeX tests the code, not the catcode).
            let hex = match (chars.get(idx + 2), chars.get(idx + 3)) {
                (Some(&a), Some(&b)) if is_hex_digit(a) && is_hex_digit(b) => {
                    Some((16 * hex_value(a) + hex_value(b), 4))
                }
                _ => None,
            };

            // Char-code form: `^^c` shifts by 64 — up below 64, down from
            // 64 on (so `^^Z` is 26, `^^M` is 13, `^^@` is 0).
            let code = match (hex, chars.get(idx + 2)) {
                (Some(resolved), _) => Some(resolved),
                (None, Some(&operand)) => {
                    let raw = operand as u32;
                    let value = if raw < 64 { raw + 64 } else { raw - 64 };
                    Some((value, 3))
                }
                (None, None) => None,
            };

            match code.and_then(|(value, consumed)| char::from_u32(value).map(|c| (c, consumed)))
            {
                Some((produced, consumed)) => {
                    out.chars.push(produced);
                    out.from_notation.push(true);
                    idx += consumed;
                }
                // Malformed pair at the very end of the line; reported
                // properly in a later milestone.
                None => idx += 2,
            }
        }

        out
    }

    /// Advance the scanner over an escape character at `chars[idx]`: read
    /// the control sequence name and set the follow-up state. Returns the
    /// characters consumed, or `None` if no character follows.
    fn scan_control_sequence(&mut self, chars: &[char], idx: usize) -> Option<usize> {
        let after = chars.get(idx + 1).copied()?;
        match self.cat.get(after) {
            CategoryCode::Letter => {
                let letters: String = chars[idx + 1..]
                    .iter()
                    .take_while(|&&c| self.cat.get(c) == CategoryCode::Letter)
                    .collect();
                let consumed = 1 + letters.chars().count();
                self.queue_cs(letters, CsKind::ControlWord, State::Quiet);
                Some(consumed)
            }
            _ => {
                let consumed = 2;
                self.queue_cs(after.to_string(), CsKind::ControlSymbol, State::Mid);
                Some(consumed)
            }
        }
    }

    fn queue_cs(&mut self, name: String, kind: CsKind, state_after: State) {
        self.queued.push_back(Token::Cs(ControlSequence { name, kind }));
        self.state = state_after;
    }
}

/// TeX's hex-digit test: by character code, regardless of catcode.
fn is_hex_digit(c: char) -> bool {
    c.is_ascii_hexdigit()
}

fn hex_value(c: char) -> u32 {
    match c {
        '0'..='9' => c as u32 - '0' as u32,
        'a'..='f' => c as u32 - 'a' as u32 + 10,
        'A'..='F' => c as u32 - 'A' as u32 + 10,
        _ => 0,
    }
}
