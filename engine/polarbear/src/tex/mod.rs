// Copyright (c) 2026 Divith123. Licensed under the MIT License.
//
// Clean-room typesetting core (ownership-ladder rung 5). Built behavior-first
// against the recorded oracle (brew `tectonic` 0.17.0, outside the repo);
// the milestone ladder lives in `ROADMAP.md`.

//! The clean-room TeX typesetting core — under construction, rung 5.
//!
//! Milestone 1 (the current state) is the input layer:
//!
//! * [`catcode`] — the 16 category codes and the mutable per-engine table.
//! * [`token`] — tokens: catcoded characters and control sequences.
//! * [`lexer`] — lines to tokens: `^^` notation, trailing-space stripping,
//!   blank-line `\par`, comment joining, and the line/character state
//!   machine.
//! * [`expand`] — the expansion processor: macros, conditionals, the
//!   expansion-only primitives.
//! * [`dim`] — fixed-point dimensions, tex.web's arithmetic rules.
//! * [`nodes`] — the node graph: glue, boxes, characters — the
//!   typesetting universe the main processor and packer build on.
//! * [`pack`] — hpack/vpack: lists into boxes with tex.web's glue
//!   fractions, badness warnings reported along the way.
//! * [`processor`] — the main processor: a mode machine over expanded
//!   tokens that builds node lists and packs them, with paragraph ends
//!   and box open/close rules.
//!
//! It is not yet wired into [`crate::CompileRequest::compile`]; that wiring
//! follows the milestone ladder (L1-L6 in doc 13 §1b).

pub mod catcode;
pub mod dim;
pub mod expand;
pub mod lexer;
pub mod nodes;
pub mod pack;
pub mod processor;
pub mod token;

pub use self::catcode::CategoryCode;
pub use self::dim::Scaled;
pub use self::lexer::Lexer;
pub use self::token::{ControlSequence, CsKind, Token};

pub use self::expand::{Expander, MacroDef, ParamPart, TeXError};
