// Copyright (c) 2026 Divith123. Licensed under the MIT License.

//! The expansion processor — layer 3 of the TeX core: macros and
//! conditionals (TeXbook ch. 20).
//!
//! The processor turns a token stream into the token stream the main
//! processor would type-set: macro calls are replaced by their bodies,
//! `\if`-family conditionals select a branch, and the expansion-only
//! primitives (`\csname`, `\string`, `\meaning`, `\number`, …) are
//! resolved. Definitions made with `\def`/`\gdef` oblige TeX's scoping:
//! `\def` inside `{…}` is undone when the group closes, `\gdef` is not.
//!
//! Control sequences live in one flat [`Expander::new`] table where a
//! user-defined macro or a primitive can hold a name; looking up by name
//! is exactly TeX's `eqtb` discipline, including `\let`-copies.
//!
//! # Architecture
//!
//! Like `tex.web` the scanner is recursive rather than a coroutine
//! driver: fetching one expanded token (`expand_token`) may bind macro
//! arguments from the remaining input, expanding those inner calls
//! recursively. An input-stack depth cap guards runaway recursion and
//! reports it as a capacity-style error. Approximations against the
//! recorded byte oracle (L6) are documented on the primitives involved:
//! `\string` details, `\meaning` spellings, and the scanning of
//! `\ifcase` inside skipped text.

use std::collections::{HashMap, VecDeque};
use std::error::Error;
use std::fmt;
use std::rc::Rc;

use super::catcode::CategoryCode;
use super::token::{ControlSequence, CsKind, Token};

/// An error raised by the expansion processor.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum TeXError {
    /// A `\par` token interrupted a macro argument scan that no `\long`
    /// prefix had licensed; the named macro's call is aborted.
    ParagraphEnded {
        /// The macro whose call was aborted.
        cs: String,
    },
    /// The input ended while a macro's arguments were still being read.
    RunawayArgument {
        /// The macro whose call was aborted.
        cs: String,
    },
    /// The input ended mid-scan; the context names the construct.
    FileEnded {
        /// The scan that met the end of input.
        context: String,
    },
    /// A conditional reached end of input without its `\fi`.
    MissingFi,
    /// An extra `\else` where no conditional branch was open.
    ExtraElse,
    /// An `\or` outside an `\ifcase` branch context.
    ExtraOr,
    /// An `\fi` with no conditional open.
    ExtraFi,
    /// `\endcsname` where no `\csname` scan was open.
    ExtraEndcsname,
    /// A control sequence was required at a scan position where none
    /// was given (the context names the construct).
    MissingCs {
        /// The scan that wanted a control sequence.
        context: String,
    },
    /// `#` was followed by something that is not a parameter number.
    IllegalParameterNumber {
        /// The macro being defined.
        cs: String,
    },
    /// `}` with no group open.
    ExtraEndGroup,
    /// An integer scan found no digits where one was required.
    MissingNumber {
        /// The construct that wanted the integer.
        context: String,
    },
    /// An integer scan exceeded the arithmetic range TeX guarantees.
    NumberTooLarge,
    /// `\global` or a prefix scan met something that is not an assignment.
    AssignmentExpected,
    /// Expansion nesting exceeded the recursion cap.
    InputStackOverflow,
    /// A control sequence token appeared where `\csname` wanted only
    /// character tokens (TeX reports "Missing \endcsname").
    MissingEndcsname,
    /// A dimension exceeded TeX's range (tex.web §101: `dimension too
    /// large`). TeX caps dimension magnitudes at 2³⁰−1 `sp` — about
    /// 16384 pt — and any operation past that aborts.
    DimensionTooLarge,
    /// A division asked for a zero divisor (tex.web's `x_over_y`
    /// guards this; the user-facing message is `division by zero`).
    DivisionByZero,
    /// A character or discretionary token reached a vertical list
    /// measurement pass — those only exist in horizontal material.
    VerticalListChar,
    /// A control sequence had no binding at main-processing time.
    UndefinedCs {
        /// The undefined sequence's name.
        name: String,
    },
    /// A token cannot reach the current mode (tex.web's `You can't use
    /// ... in ~~ mode` errors).
    NotInMode {
        /// How the token describes itself (`\macro`, `^`).
        what: String,
        /// The mode's tex.web name (`vertical mode`, `horizontal mode`,
        /// `internal vertical mode`).
        mode: &'static str,
    },
    /// A unit scan found letters that match no known unit.
    IllegalUnit {
        /// The construct that was scanning (`\hskip`, `\vrule`).
        context: String,
    },
    /// A `{` was required where the stream moved on (tex.web's
    /// `Missing { inserted`).
    MissingBrace,
}

impl fmt::Display for TeXError {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        match self {
            Self::ParagraphEnded { cs } => write!(f, "Paragraph ended before \\{cs} was complete."),
            Self::RunawayArgument { cs } => {
                write!(f, "Runaway argument? File ended while scanning use of \\{cs}.")
            }
            Self::FileEnded { context } => {
                write!(f, "File ended while scanning use of {context}.")
            }
            Self::MissingFi => write!(f, "Missing \\fi inserted."),
            Self::ExtraElse => write!(f, "Extra \\else."),
            Self::ExtraOr => write!(f, "Extra \\or."),
            Self::ExtraFi => write!(f, "Extra \\fi."),
            Self::ExtraEndcsname => write!(f, "Extra \\endcsname."),
            Self::ExtraEndGroup => write!(f, "Extra }}."),
            Self::MissingCs { context } => {
                write!(f, "Missing control sequence inserted ({context}).")
            }
            Self::IllegalParameterNumber { cs } => {
                write!(f, "Illegal parameter number in definition of \\{cs}.")
            }
            Self::MissingNumber { context } => write!(f, "Missing number, treated as zero ({context})."),
            Self::NumberTooLarge => write!(f, "Number too large."),
            Self::AssignmentExpected => write!(f, "Assignment expected after prefix."),
            Self::InputStackOverflow => write!(f, "TeX capacity exceeded: input stack size."),
            Self::MissingEndcsname => write!(f, "Missing \\endcsname inserted."),
            Self::DimensionTooLarge => write!(f, "Dimension too large."),
            Self::DivisionByZero => write!(f, "Division by zero."),
            Self::VerticalListChar => write!(f, "A character token appeared in a vertical list."),
            Self::UndefinedCs { name } => write!(f, "Undefined control sequence. \\{name}"),
            Self::NotInMode { what, mode } => {
                write!(f, "You can't use `{what}' in {mode}.")
            }
            Self::IllegalUnit { context } => {
                write!(f, "Illegal unit of measure (pt inserted) ({context}).")
            }
            Self::MissingBrace => write!(f, "Missing {{ inserted."),
        }
    }
}

impl Error for TeXError {}

/// A macro definition: its parameter list, replacement body, and the
/// `\long` flag.
///
/// * `parts` holds one [`ParamPart`] per parameter, in source order:
///   `#1x#2` is `Delim("x"), Undelim` (the `x` is #1's own terminator),
///   `#1#2` is `Undelim, Undelim`. Leading parameter-text tokens (before
///   the first `#`) are dropped at this layer, recorded as an L6 note.
/// * `body` holds the replacement text with parameter references stored
///   as `Token::Parameter(slot)`; a literal `##` became a catcode-6 `#`
///   character token, exactly as TeX substitutes at call time.
/// * `long` records a `\long` prefix; without it a `\par` in the
///   arguments aborts the call.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct MacroDef {
    /// The parameter text, delimiter/slot interleaved in order.
    pub parts: Vec<ParamPart>,
    /// The replacement text with `Token::Parameter` placeholders.
    pub body: Vec<Token>,
    /// Whether `\long` licenses `\par` tokens in the arguments.
    pub long: bool,
}

/// One macro parameter's calling convention, in param-text order.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum ParamPart {
    /// A delimited parameter: the call collects tokens (expanding as
    /// needed) until this exact token run matches, braces preserved
    /// inside the argument. This is the parameter's own terminator.
    Delim(Vec<Token>),
    /// An undelimited parameter: one token after spaces are skipped,
    /// or a braced group whose outer braces are stripped (inner braces
    /// kept).
    Undelim,
}

/// A primitive (the parts of TeX's expansion machinery we implement at
/// this layer). Names live in the same namespace as macros: `\let` or
/// `\def` of a primitive name replaces it, per TeX.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum Prim {
    /// `\def`/`\gdef`/`\edef`/`\xdef`: `gdef`/`xdef` carry the flags
    /// TeX stores them as (plain/LaTeX define them as macros; we take
    /// the spelled forms as primitives).
    Def { global: bool, edef: bool },
    /// `\let`, or `\futurelet` when `future`.
    Let { future: bool },
    /// `\expandafter`.
    ExpandAfter,
    /// `\noexpand`: the next token round-trips unexpanded once.
    NoExpand,
    /// The `\if` family. TeX implements `\iftrue`/`\iffalse` as distinct
    /// comparisons over `\relax`; we give them a direct kind.
    If(IfKind),
    Csxname,
    EndCsname,
    String,
    Meaning,
    Number,
    Relax,
    Else,
    Or,
    Fi,
    /// `\begingroup` / `\endgroup`, which scope `\def` like `{}` does.
    Begingroup,
    Endgroup,
    /// The `\global`/`\long` prefixes (TeX's `\outer` is accepted but
    /// has no enforcement at this layer — documented as L3+ work).
    Global,
    Long,
    Outer,
}

/// Which `\if…` comparison.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum IfKind {
    /// `\if`: two tokens after full expansion.
    Char,
    /// `\ifx`: two tokens without expansion.
    X,
    /// `\ifnum`: two integers.
    Num,
    /// `\ifcase`: branch by integer.
    Case,
    /// `\iftrue`.
    True,
    /// `\iffalse`.
    False,
}

/// The one-step outcome of [`Expander::expand_step`]: materialized for
/// the caller (`Got`), consumed internally (`Again`), or the input ran
/// dry (`Exhausted`).
enum Step {
    /// A materialized token for the caller.
    Got(Token),
    /// Consumed internally; keep cycling.
    Again,
    /// Input drained.
    Exhausted,
}

/// What a control-sequence name is bound to.
#[derive(Clone)]
enum CsEntry {
    /// A user-defined macro (owned via `Rc` so `\let` copies are cheap).
    Macro(Rc<MacroDef>),
    /// A primitive.
    Prim(Prim),
    /// The "meaning of a character token" that `\let` can copy
    /// (a category-coded character).
    CharMeaning(char, CategoryCode),
    /// `\csname …\endcsname` produced a name never defined: TeX's
    /// undefined-cs meaning.
    Undefined,
}

/// The state of one open conditional.
struct CondState {
    kind: IfKind,
    branch: BranchState,
    else_seen: bool,
}

/// Where the conditional's tokens are headed.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum BranchState {
    /// The selected branch flows to the main processor.
    Selected,
    /// Waiting before branch `n` (n = remaining `\or`s to step past;
    /// used by `\ifcase` and by branch pointers of the other kinds).
    Waiting(i64),
    /// Skipping drops tokens until the next `\or`/`\else`/`\fi`.
    Dropping,
    /// Pushed while an outer conditional was skipping: everything
    /// balances to this conditional's `\fi` (TeX's passed-conditional
    /// discipline).
    Locked,
}
/// The per-run expansion state: the table and scopes TeX's `eqtb` lives
/// in. Construct once per engine run; definitions persist across `run`
/// calls, exactly as a session of `\input`s would.
pub struct Expander {
    /// Control-sequence bindings.
    table: HashMap<String, CsEntry>,
    /// Open groups; each holds the undo log of its scoped definitions
    /// (`None` restores to "never defined").
    groups: Vec<Vec<(String, Option<CsEntry>)>>,
    /// Open `\if` conditionals, outermost first.
    conds: Vec<CondState>,
    /// The `\noexpand` mark: the very next fetched token round-trips
    /// unexpanded once.
    noexpand: bool,
    /// Set when the token about to be routed carries the `\noexpand`
    /// mark; consumed by `route` exactly once.
    frozen: bool,
    /// Open input layers; the backmost layer is the current input,
    /// popped front-first.
    layers: Vec<VecDeque<Token>>,
    /// Current expansion nesting, against the depth cap.
    depth: usize,
}

/// How far expansion nesting may go before a capacity error. TeX's own
/// input-stack limit is comparable.
const MAX_DEPTH: usize = 200;

impl Default for Expander {
    /// The empty processor; see [`Expander::new`].
    fn default() -> Self {
        Self::new()
    }
}

impl Expander {
    /// A fresh processor with an empty table (every primitive resolves
    /// by name; only `\let`-copies of them materialize entries).
    #[must_use]
    pub fn new() -> Self {
        Self {
            table: HashMap::new(),
            groups: Vec::new(),
            conds: Vec::new(),
            noexpand: false,
            frozen: false,
            layers: Vec::new(),
            depth: 0,
        }
    }

    /// Push a token stream onto the input and expand until it is
    /// drained; returns the tokens handed to the main processor.
    ///
    /// # Errors
    /// [`TeXError`] for the expansion contract violations (runaway
    /// arguments, unbalanced conditionals, illegal `#`s, overrun
    /// numbers).
    pub fn run(&mut self, tokens: Vec<Token>) -> Result<Vec<Token>, TeXError> {
        let mut out = Vec::new();
        self.layers.push(VecDeque::from(tokens));
        loop {
            let token = if self.skipped() {
                // In a dropped region nothing expands: a raw fetch
                // keeps the skip bookkeeping cheap and side-effect
                // free.
                self.get_token()
            } else {
                self.next_expanded()?
            };
            let Some(token) = token else {
                break;
            };
            self.route(token, &mut out)?;
        }
        if let Some(context) = self.unfinished() {
            return Err(context);
        }
        Ok(out)
    }

    /// Post-input contract checks: conditionals, groups that opened at
    /// this layer, scans hung on EOF.
    fn unfinished(&self) -> Option<TeXError> {
        if self.conds.is_empty() {
            if self.groups.is_empty() {
                return None;
            }
            return Some(TeXError::FileEnded { context: String::from("\\begingroup") });
        }
        Some(TeXError::MissingFi)
    }

    /// The next materialized token: fully expanded, with the
    /// `\noexpand` mark caught; `None` terminates the input.
    fn next_expanded(&mut self) -> Result<Option<Token>, TeXError> {
        self.depth += 1;
        if self.depth > MAX_DEPTH {
            self.depth -= 1;
            return Err(TeXError::InputStackOverflow);
        }
        let token = loop {
            match self.expand_step()? {
                Step::Got(token) => break Some(token),
                Step::Again => {}
                Step::Exhausted => break None,
            }
        };
        self.depth -= 1;
        Ok(token)
    }

    /// One cycle of the expansion loop.
    fn expand_step(&mut self) -> Result<Step, TeXError> {
        let Some(token) = self.get_token() else {
            return Ok(Step::Exhausted);
        };
        if self.noexpand {
            self.noexpand = false;
            self.frozen = true;
            // The mark lands on whatever token follows, whatever it is;
            // a character round-trips too (TeX rejects the form, ours
            // passes it through — an L6 tuning note).
            return Ok(Step::Got(token));
        }
        let Token::Cs(cs) = &token else {
            return Ok(Step::Got(token));
        };
        let name = cs.name.clone();
        match self.entry(&name) {
            Some(CsEntry::Macro(def)) => {
                self.call_macro(&name, def)?;
                Ok(Step::Again)
            }
            Some(CsEntry::CharMeaning(c, cat)) => Ok(Step::Got(Token::Char(c, cat))),
            Some(CsEntry::Prim(p)) => {
                if prim_expands(p) {
                    if let Some(produced) = self.exec_prim(p, &name)? {
                        self.push_front(produced);
                    }
                    Ok(Step::Again)
                } else {
                    // `\def`, `\let`, `\relax`, the `\fi` group … are
                    // main-processor semantics; leave them for `route`.
                    Ok(Step::Got(token))
                }
            }
            Some(CsEntry::Undefined) | None => Ok(Step::Got(token)),
        }
    }

    /// The next raw input token, discarding empty layers.
    fn get_token(&mut self) -> Option<Token> {
        while let Some(layer) = self.layers.last_mut() {
            if let Some(token) = layer.pop_front() {
                return Some(token);
            }
            self.layers.pop();
        }
        None
    }

    /// Make `tokens` the next input (in order), without touching the
    /// existing stream.
    fn push_front(&mut self, tokens: Vec<Token>) {
        if tokens.is_empty() {
            return;
        }
        self.layers.push(tokens.into());
    }

    fn token_front(&mut self, token: Token) {
        self.push_front(vec![token]);
    }

    /// The next raw token, read but left in place (the `\futurelet`
    /// probe).
    fn peek_token(&mut self) -> Option<Token> {
        let token = self.get_token()?;
        self.token_front(token.clone());
        Some(token)
    }

    /// The binding of `name`: the table first (a `\def` of a primitive
    /// name replaced it), then the primitive namespace.
    fn entry(&self, name: &str) -> Option<CsEntry> {
        if let Some(entry) = self.table.get(name) {
            return Some(entry.clone());
        }
        prim_of_name(name).map(CsEntry::Prim)
    }

    /// Bind a name, recording undo state unless `global`. Every local
    /// bind logs the pre-group value — including "never defined" — so
    /// a group close restores TeX's save-stack shape exactly.
    fn bind(&mut self, name: &str, entry: CsEntry, global: bool) {
        if !global {
            let old = self.entry(name);
            if let Some(log) = self.groups.last_mut() {
                log.push((name.to_string(), old));
            }
        }
        self.table.insert(name.to_string(), entry);
    }
}

/// The primitive of a plain table name (`def` → `\def`), or `None` when
/// nothing is bound there.
fn prim_of_name(name: &str) -> Option<Prim> {
    match name {
        "def" => Some(Prim::Def { global: false, edef: false }),
        "gdef" => Some(Prim::Def { global: true, edef: false }),
        "edef" => Some(Prim::Def { global: false, edef: true }),
        "xdef" => Some(Prim::Def { global: true, edef: true }),
        "let" => Some(Prim::Let { future: false }),
        "futurelet" => Some(Prim::Let { future: true }),
        "expandafter" => Some(Prim::ExpandAfter),
        "noexpand" => Some(Prim::NoExpand),
        "if" => Some(Prim::If(IfKind::Char)),
        "ifx" => Some(Prim::If(IfKind::X)),
        "ifnum" => Some(Prim::If(IfKind::Num)),
        "ifcase" => Some(Prim::If(IfKind::Case)),
        "iftrue" => Some(Prim::If(IfKind::True)),
        "iffalse" => Some(Prim::If(IfKind::False)),
        "csname" => Some(Prim::Csxname),
        "endcsname" => Some(Prim::EndCsname),
        "string" => Some(Prim::String),
        "meaning" => Some(Prim::Meaning),
        "number" => Some(Prim::Number),
        "relax" => Some(Prim::Relax),
        "else" => Some(Prim::Else),
        "or" => Some(Prim::Or),
        "fi" => Some(Prim::Fi),
        "begingroup" => Some(Prim::Begingroup),
        "endgroup" => Some(Prim::Endgroup),
        "global" => Some(Prim::Global),
        "long" => Some(Prim::Long),
        "outer" => Some(Prim::Outer),
        _ => None,
    }
}

/// Substitute macro arguments into a definition body: `Parameter(slot)`
/// tokens expand to the bound argument; a body slot without a bound
/// argument is a definition-scan bug.
fn substitute(cs: &str, def: &MacroDef, args: &[Vec<Token>]) -> Result<Vec<Token>, TeXError> {
    let mut out = Vec::new();
    for token in &def.body {
        match token {
            Token::Parameter(slot) => {
                let Some(arg) = args.get(*slot as usize) else {
                    return Err(TeXError::IllegalParameterNumber { cs: cs.to_string() });
                };
                out.extend(arg.iter().cloned());
            }
            other => out.push(other.clone()),
        }
    }
    Ok(out)
}
impl Expander {
    /// Main-processor routing for one materialized token: inside a
    /// skipped region only the conditional bookkeeping runs (everything
    /// else drops, unexpanded); otherwise group bookkeeping for brace
    /// characters, the main semantics of control sequences at flow
    /// positions, and pass-through emission in between. A
    /// `\noexpand`-frozen token is emitted exactly as it stands,
    /// without expansion.
    fn route(&mut self, token: Token, out: &mut Vec<Token>) -> Result<(), TeXError> {
        let frozen = std::mem::take(&mut self.frozen);
        if self.skipped() {
            return self.route_skipped(token);
        }
        match token {
            // Group braces: tex.web's main processing opens a save
            // group and hands on a marker so the main processor's
            // containers (box bodies) open at the right points; the
            // brace characters themselves never typeset.
            Token::Char(_, CategoryCode::BeginGroup) => {
                self.groups.push(Vec::new());
                out.push(Token::GroupBegin);
            }
            Token::Char(_, CategoryCode::EndGroup) => {
                let Some(log) = self.groups.pop() else {
                    return Err(TeXError::ExtraEndGroup);
                };
                undo_entries(self, log);
                out.push(Token::GroupEnd);
            }
            Token::Char(..) | Token::Parameter(_) => out.push(token),
            // Group markers never carry a binding of their own; they
                // flow through as the main processor's container book.
            Token::GroupBegin | Token::GroupEnd => out.push(token),
            Token::Cs(_) if frozen => out.push(token),
            Token::Cs(cs) => {
                let name = cs.name.clone();
                match self.entry(&name) {
                    Some(CsEntry::Macro(def)) => self.call_macro(&name, def)?,
                    Some(CsEntry::CharMeaning(c, cat)) => out.push(Token::Char(c, cat)),
                    Some(CsEntry::Prim(p)) => {
                        if let Some(produced) = self.exec_prim(p, &name)? {
                            self.push_front(produced);
                        }
                    }
                    Some(CsEntry::Undefined) | None => out.push(Token::Cs(cs)),
                }
            }
        }
        Ok(())
    }
}

/// What a primitive's produced expansion looks like: tokens to re-input
/// in front, or a side effect only (`None`).
type Produce = Option<Vec<Token>>;

/// TeX's assignment flags, gathered from the `\global`/`\long`/`\outer`
/// prefix scan.
#[derive(Default, Clone, Copy)]
struct AssignFlags {
    global: bool,
    long: bool,
    outer: bool,
}

impl Expander {
    /// Execute one primitive; `name` is how it was reached, for error
    /// messages.
    fn exec_prim(&mut self, p: Prim, name: &str) -> Result<Produce, TeXError> {
        match p {
            Prim::Def { global, edef } => {
                self.scan_def(name, AssignFlags { global, ..AssignFlags::default() }, edef)?;
                Ok(None)
            }
            Prim::Let { future } => {
                self.scan_let(AssignFlags::default(), future)?;
                Ok(None)
            }
            Prim::Global => {
                self.assignment(AssignFlags { global: true, ..AssignFlags::default() })?;
                Ok(None)
            }
            Prim::Long => {
                self.assignment(AssignFlags { long: true, ..AssignFlags::default() })?;
                Ok(None)
            }
            Prim::Outer => {
                self.assignment(AssignFlags { outer: true, ..AssignFlags::default() })?;
                Ok(None)
            }
            Prim::ExpandAfter => {
                self.scan_after()?;
                Ok(None)
            }
            Prim::NoExpand => {
                // TeX pins the mark onto the *next* token; we pop it,
                // set the flag, and make it the next fetch — the same
                // one-shot round-trip.
                let Some(token) = self.get_token() else {
                    return Err(TeXError::FileEnded { context: String::from("\\noexpand") });
                };
                self.noexpand = true;
                self.token_front(token);
                Ok(None)
            }
            Prim::If(kind) => {
                self.open_cond(kind)?;
                Ok(None)
            }
            Prim::Else => {
                self.saw_else()?;
                Ok(None)
            }
            Prim::Or => {
                self.saw_or()?;
                Ok(None)
            }
            Prim::Fi => {
                if self.conds.pop().is_none() {
                    return Err(TeXError::ExtraFi);
                }
                Ok(None)
            }
            Prim::Begingroup => {
                self.groups.push(Vec::new());
                Ok(None)
            }
            Prim::Endgroup => {
                self.close_group()?;
                Ok(None)
            }
            Prim::Csxname => Ok(Some(vec![self.scan_csname()?])),
            Prim::EndCsname => Err(TeXError::ExtraEndcsname),
            Prim::String => Ok(Some(self.string_of())),
            Prim::Meaning => Ok(Some(self.meaning_of())),
            Prim::Number => {
                let value = self.scan_number("\\number")?;
                Ok(Some(number_tokens(value)))
            }
            Prim::Relax => Ok(None),
        }
    }

    /// The prefix-absorbing assignment loop: fetch control sequences,
    /// absorbing `\global`/`\long`/`\outer` prefixes, then execute the
    /// assignment (`\def`-family or `\let`-family); anything else is an
    /// error.
    fn assignment(&mut self, mut flags: AssignFlags) -> Result<(), TeXError> {
        loop {
            let Some(Token::Cs(cs)) = self.get_token() else {
                return Err(TeXError::AssignmentExpected);
            };
            let name = cs.name.clone();
            match self.entry(&name) {
                Some(CsEntry::Prim(Prim::Global)) => flags.global = true,
                Some(CsEntry::Prim(Prim::Long)) => flags.long = true,
                Some(CsEntry::Prim(Prim::Outer)) => flags.outer = true,
                Some(CsEntry::Prim(Prim::Def { global: def_global, edef })) => {
                    flags.global = flags.global || def_global;
                    return self.scan_def(&name, flags, edef);
                }
                Some(CsEntry::Prim(Prim::Let { future })) => {
                    return self.scan_let(flags, future);
                }
                _ => return Err(TeXError::AssignmentExpected),
            }
        }
    }

    /// Read `\def ⟨name⟩ ⟨parameter text⟩{⟨replacement⟩}`: parameters
    /// numbered consecutively (`#1…#9`), `##` a literal `#`, the body
    /// brace-balanced with `Parameter(slot)` placeholders. `\edef`
    /// expands the body after it is grabbed.
    fn scan_def(&mut self, called_as: &str, flags: AssignFlags, edef: bool) -> Result<(), TeXError> {
        let Some(Token::Cs(target)) = self.get_token() else {
            return Err(TeXError::MissingCs { context: String::from("\\def") });
        };
        let name = target.name.clone();

        // Parameter text, up to the opening brace: `#n` starts a
        // parameter (numbers consecutive from #1); the tokens between
        // a parameter and the next `#`/`{` are that parameter's own
        // delimiter. Tokens before the first `#` would be call-time
        // literals in TeX; they are dropped here (L6 note).
        let mut parts: Vec<ParamPart> = Vec::new();
        let mut delim: Vec<Token> = Vec::new();
        let mut slots = 0u8;
        loop {
            let Some(token) = self.get_token() else {
                return Err(TeXError::FileEnded { context: String::from("\\def") });
            };
            match token {
                Token::Char(_, CategoryCode::BeginGroup) => {
                    Self::commit_delim(&mut parts, &mut delim);
                    break;
                }
                Token::Char('#', CategoryCode::Parameter) => {
                    self.def_param_token(called_as, &mut parts, &mut slots, &mut delim)?;
                }
                other => delim.push(other),
            }
        }

        // Replacement body, brace-balanced, up to its closing brace.
        let mut body = Vec::new();
        let mut depth = 1usize;
        while let Some(token) = self.get_token() {
            match token {
                Token::Char(_, CategoryCode::BeginGroup) => {
                    depth += 1;
                    body.push(token);
                }
                Token::Char(_, CategoryCode::EndGroup) => {
                    depth -= 1;
                    if depth == 0 {
                        break;
                    }
                    body.push(token);
                }
                Token::Char('#', CategoryCode::Parameter) => {
                    self.def_body_param(called_as, &mut body, slots)?;
                }
                other => body.push(other),
            }
        }
        let body = if edef { self.scan_edef_body(called_as, body)? } else { body };
        let def = Rc::new(MacroDef { parts, body, long: flags.long });
        self.bind(&name, CsEntry::Macro(def), flags.global);
        Ok(())
    }

    /// Give the latest parameter its delimiter from the buffer — an
    /// empty buffer leaves the undelimited convention — and clear it.
    fn commit_delim(parts: &mut [ParamPart], delim: &mut Vec<Token>) {
        if !delim.is_empty() && !parts.is_empty() {
            let cloned = std::mem::take(delim);
            let len = parts.len();
            parts[len - 1] = ParamPart::Delim(cloned);
            return;
        }
        delim.clear();
    }

    /// One `#` in the parameter text: the digit must continue the
    /// parameters declared so far in order (`#1`, `#2`, …); anything
    /// else is TeX's illegal-parameter error.
    fn def_param_token(
        &mut self,
        called_as: &str,
        parts: &mut Vec<ParamPart>,
        slots: &mut u8,
        delim: &mut Vec<Token>,
    ) -> Result<(), TeXError> {
        let Some(operand) = self.get_token() else {
            return Err(TeXError::FileEnded { context: String::from("\\def") });
        };
        match operand {
            Token::Char(n, _) if (n.is_ascii_digit() && n != '0') => {
                let slot = n as u8 - b'0' - 1;
                if slot != *slots {
                    return Err(TeXError::IllegalParameterNumber { cs: called_as.to_string() });
                }
                Self::commit_delim(parts, delim);
                parts.push(ParamPart::Undelim);
                *slots += 1;
            }
            _ => return Err(TeXError::IllegalParameterNumber { cs: called_as.to_string() }),
        }
        Ok(())
    }

    /// One `#` in the replacement body: a parameter reference (bounded
    /// by the slots defined), or the literal `##`.
    fn def_body_param(
        &mut self,
        called_as: &str,
        body: &mut Vec<Token>,
        slots: u8,
    ) -> Result<(), TeXError> {
        let Some(operand) = self.get_token() else {
            return Err(TeXError::FileEnded { context: String::from("\\def") });
        };
        match operand {
            Token::Char('#', CategoryCode::Parameter) => {
                body.push(Token::Char('#', CategoryCode::Parameter));
            }
            Token::Char(n, _) if (n.is_ascii_digit() && n != '0') => {
                let slot = n as u8 - b'0' - 1;
                if slot >= slots {
                    return Err(TeXError::IllegalParameterNumber { cs: called_as.to_string() });
                }
                body.push(Token::Parameter(slot));
            }
            _ => return Err(TeXError::IllegalParameterNumber { cs: called_as.to_string() }),
        }
        Ok(())
    }

    /// Read `\let ⟨target⟩ ⟨=⟩ ⟨one token⟩` (the value is fetched
    /// without expansion), or `\futurelet ⟨target⟩ ⟨cs⟩ ⟨peeked⟩`,
    /// which leaves the peeked token in the input.
    fn scan_let(&mut self, flags: AssignFlags, future: bool) -> Result<(), TeXError> {
        let Some(Token::Cs(target)) = self.get_token() else {
            return Err(TeXError::MissingCs { context: String::from("\\let") });
        };
        let name = target.name.clone();
        if future {
            let entry = match self.peek_token() {
                Some(Token::Cs(cs)) => self.entry(&cs.name).unwrap_or(CsEntry::Undefined),
                Some(Token::Char(c, cat)) => CsEntry::CharMeaning(c, cat),
                _ => CsEntry::Undefined,
            };
            self.bind(&name, entry, flags.global);
            return Ok(());
        }
        // Optional spaces, one optional '=', optional spaces.
        loop {
            let Some(token) = self.get_token() else {
                return Err(TeXError::FileEnded { context: String::from("\\let") });
            };
            match token {
                Token::Char(' ', CategoryCode::Space) => continue,
                Token::Char('=', CategoryCode::Other) => break,
                _ => {
                    self.token_front(token);
                    break;
                }
            }
        }
        loop {
            let Some(token) = self.get_token() else {
                return Err(TeXError::FileEnded { context: String::from("\\let") });
            };
            if !matches!(token, Token::Char(' ', CategoryCode::Space)) {
                self.token_front(token);
                break;
            }
        }
        let entry = match self.get_token() {
            Some(Token::Cs(cs)) => self.entry(&cs.name).unwrap_or(CsEntry::Undefined),
            Some(Token::Char(c, cat)) => CsEntry::CharMeaning(c, cat),
            Some(_) => CsEntry::Undefined,
            None => return Err(TeXError::FileEnded { context: String::from("\\let") }),
        };
        self.bind(&name, entry, flags.global);
        Ok(())
    }

    /// `\expandafter ⟨a⟩ ⟨b⟩`: `b` is expanded once; `a` re-enters the
    /// input ahead of `b`'s expansion (TeX's save-back ordering), so
    /// `\expandafter\show\csname…` lets `\show` probe the result. An
    /// unexpandable `b` round-trips the pair untouched.
    fn scan_after(&mut self) -> Result<(), TeXError> {
        let Some(a) = self.get_token() else {
            return Err(TeXError::FileEnded { context: String::from("\\expandafter") });
        };
        let Some(b) = self.get_token() else {
            return Err(TeXError::FileEnded { context: String::from("\\expandafter") });
        };
        let expanded = match &b {
            Token::Cs(cs) => {
                let name = cs.name.clone();
                match self.entry(&name) {
                    Some(CsEntry::Macro(def)) => self.call_macro(&name, def)?,
                    Some(CsEntry::Prim(p)) if prim_expands(p) => {
                        if let Some(produced) = self.exec_prim(p, &name)? {
                            self.push_front(produced);
                        }
                    }
                    _ => {
                        self.push_front(vec![a, b]);
                        return Ok(());
                    }
                }
                true
            }
            _ => false,
        };
        if expanded {
            // The expansion lives on a layer below; `a` goes above it,
            // so it is processed first.
            self.push_front(vec![a]);
        } else {
            self.push_front(vec![a, b]);
        }
        Ok(())
    }

    /// `\csname …\endcsname`: build the name from character tokens
    /// (expanding as needed); brace characters contribute nothing (TeX
    /// skips them — an L6 tuning note), a stray non-`\endcsname`
    /// control token is an error.
    fn scan_csname(&mut self) -> Result<Token, TeXError> {
        let mut name = String::new();
        loop {
            let Some(token) = self.next_expanded()? else {
                return Err(TeXError::FileEnded { context: String::from("\\csname") });
            };
            match token {
                Token::Char(_, CategoryCode::BeginGroup)
                | Token::Char(_, CategoryCode::EndGroup)
                | Token::GroupBegin
                | Token::GroupEnd => {}
                Token::Char(c, _) => name.push(c),
                Token::Cs(cs) if cs.name == "endcsname" => break,
                Token::Cs(_) => return Err(TeXError::MissingEndcsname),
                Token::Parameter(_) => {}
            }
        }
        Ok(Token::Cs(ControlSequence { name, kind: CsKind::ControlWord }))
    }

    /// `\string⟨token⟩`: escape character plus the name's characters,
    /// catcode 12 (a space inside a single-character cs name is
    /// catcode 10). A non-cs token round-trips unchanged.
    fn string_of(&mut self) -> Vec<Token> {
        let mut out = Vec::new();
        match self.get_token() {
            Some(Token::Cs(cs)) => {
                out.push(Token::Char('\\', CategoryCode::Other));
                for c in cs.name.chars() {
                    if c == ' ' {
                        out.push(Token::Char(' ', CategoryCode::Space));
                    } else {
                        out.push(Token::Char(c, CategoryCode::Other));
                    }
                }
            }
            Some(token) => out.push(token),
            None => {}
        }
        out
    }

    /// `\meaning⟨token⟩`: prints the token's meaning as characters.
    /// Macros read `\macro:->⟨body⟩`; primitives appear by name with a
    /// leading backslash. Exact spellings are an L6 tuning note.
    fn meaning_of(&mut self) -> Vec<Token> {
        let Some(token) = self.get_token() else {
            return Vec::new();
        };
        let text: String = match token {
            Token::Cs(cs) => match self.entry(&cs.name) {
                Some(CsEntry::Macro(def)) => {
                    let mut text = String::from("\\macro:->");
                    for piece in &def.body {
                        text.push_str(&piece.to_string());
                    }
                    text
                }
                _ => format!("\\{}", cs.name),
            },
            other => other.to_string(),
        };
        text.chars()
            .map(|c| {
                if c == ' ' {
                    Token::Char(' ', CategoryCode::Space)
                } else {
                    Token::Char(c, CategoryCode::Other)
                }
            })
            .collect()
    }
}

impl Expander {
    /// Macro call: bind the arguments, substitute, and push the body as
    /// the next input layer.
    fn call_macro(&mut self, name: &str, def: Rc<MacroDef>) -> Result<(), TeXError> {
        let args = self.scan_args(name, &def)?;
        let body = substitute(name, &def, &args)?;
        self.layers.push(body.into());
        Ok(())
    }

    /// Bind the arguments of a macro call (TeXbook ch. 20): delimited
    /// parameters collect tokens (expanding) until their delimiter
    /// matches, braces preserved; undelimited parameters take one token
    /// after spaces are skipped, or a braced group grabbed without
    /// expansion, outer braces stripped. A `\par` aborts the scan
    /// unless the macro is `\long`.
    fn scan_args(&mut self, cs: &str, def: &MacroDef) -> Result<Vec<Vec<Token>>, TeXError> {
        let runaway = TeXError::RunawayArgument { cs: cs.to_string() };
        let mut args: Vec<Vec<Token>> = Vec::new();
        for part in &def.parts {
            match part {
                ParamPart::Undelim => {
                    let token = loop {
                        let Some(tok) = self.next_expanded()? else {
                            return Err(runaway.clone());
                        };
                        if matches!(tok, Token::Char(_, CategoryCode::Space)) {
                            continue;
                        }
                        if matches!(&tok, Token::Cs(c) if c.name == "par") && !def.long {
                            return Err(TeXError::ParagraphEnded { cs: cs.to_string() });
                        }
                        break tok;
                    };
                    if matches!(token, Token::Char(_, CategoryCode::BeginGroup)) {
                        args.push(self.grab_raw_group(cs)?);
                    } else {
                        args.push(vec![token]);
                    }
                }
                ParamPart::Delim(delim) => {
                    // Collect tokens until the whole delimiter run
                    // matches; the delimiter itself is consumed. Feb
                    // brace nesting protects inner delimiters, and a
                    // failed partial match turns the probe characters
                    // into argument data (TeX re-reads them).
                    let mut arg: Vec<Token> = Vec::new();
                    let mut pending: VecDeque<Token> = VecDeque::new();
                    let mut depth = 0usize;
                    let mut idx = 0usize;
                    while idx < delim.len() {
                        let Some(token) = self.next_expanded()? else {
                            return Err(runaway.clone());
                        };
                        if matches!(&token, Token::Cs(c) if c.name == "par") && !def.long {
                            return Err(TeXError::ParagraphEnded { cs: cs.to_string() });
                        }
                        match &token {
                            Token::Char(_, CategoryCode::BeginGroup) => {
                                depth += 1;
                                arg.extend(pending.drain(..));
                                arg.push(token);
                                idx = 0;
                                continue;
                            }
                            Token::Char(_, CategoryCode::EndGroup) => {
                                if depth == 0 {
                                    return Err(TeXError::ExtraEndGroup);
                                }
                                depth -= 1;
                                arg.extend(pending.drain(..));
                                arg.push(token);
                                idx = 0;
                                continue;
                            }
                            _ => {}
                        }
                        if depth == 0 && Some(&token) == delim.get(idx) {
                            pending.push_back(token);
                            idx += 1;
                            continue;
                        }
                        // Mismatch: the probe characters are argument
                        // data, and the delimiter search restarts.
                        arg.extend(pending.drain(..));
                        idx = 0;
                        arg.push(token);
                    }
                    Self::strip_single_pair(&mut arg);
                    args.push(arg);
                }
            }
        }
        Ok(args)
    }

    /// A delimited argument grabbed as a whole braced group loses its
    /// outer pair (tectonic oracle, `\tracingmacros`: `#1<-b c` for
    /// `{b c}`, but `#1<-{a} {b}` when the argument holds more than
    /// that single group). Inner braces survive unharmed.
    fn strip_single_pair(arg: &mut Vec<Token>) {
        let Some(Token::Char(_, CategoryCode::BeginGroup)) = arg.first() else {
            return;
        };
        let Some(Token::Char(_, CategoryCode::EndGroup)) = arg.last() else {
            return;
        };
        let mut depth = 1usize;
        for token in arg[1..arg.len() - 1].iter() {
            match token {
                Token::Char(_, CategoryCode::BeginGroup) => depth += 1,
                Token::Char(_, CategoryCode::EndGroup) => {
                    depth -= 1;
                    if depth == 0 {
                        return;
                    }
                }
                _ => {}
            }
        }
        arg.remove(arg.len() - 1);
        arg.remove(0);
    }

    /// A balanced braced group grabbed without expansion (the braces of
    /// an undelimited argument); the outer braces are stripped, inner
    /// nested braces stay.
    fn grab_raw_group(&mut self, cs: &str) -> Result<Vec<Token>, TeXError> {
        let mut group = Vec::new();
        let mut depth = 1usize;
        while let Some(token) = self.get_token() {
            match token {
                Token::Char(_, CategoryCode::BeginGroup) => {
                    depth += 1;
                    group.push(token);
                }
                Token::Char(_, CategoryCode::EndGroup) => {
                    depth -= 1;
                    if depth == 0 {
                        break;
                    }
                    group.push(token);
                }
                other => group.push(other),
            }
        }
        if depth != 0 {
            return Err(TeXError::RunawayArgument { cs: cs.to_string() });
        }
        Ok(group)
    }

    /// The `\edef` body expansion: a bounded expansion pass over the
    /// grabbed body, sharing the table. Definitions made inside an
    /// `\edef` body do not commit (an L6 tuning note), and
    /// conditionals/groups inside it are approximate at this layer. A
    /// sentinel below the body's layer marks the boundary exactly:
    /// macro bodies pushed while expanding belong to the body; the
    /// base input does not.
    fn scan_edef_body(&mut self, _called_as: &str, body: Vec<Token>) -> Result<Vec<Token>, TeXError> {
        if body.is_empty() {
            return Ok(body);
        }
        let sentinel = Token::Cs(ControlSequence {
            name: String::from(" polarbear-edef-sentinel"),
            kind: CsKind::ControlWord,
        });
        self.layers.push(vec![sentinel.clone()].into());
        self.layers.push(body.into());
        let mut expanded = Vec::new();
        while let Some(token) = self.next_expanded()? {
            if token == sentinel {
                break;
            }
            expanded.push(token);
        }
        Ok(expanded)
    }

    /// True while any conditional is not in its selected branch, i.e.
    /// the flow is inside a dropped region.
    fn skipped(&self) -> bool {
        match self.conds.last() {
            Some(c) => !matches!(c.branch, BranchState::Selected),
            None => false,
        }
    }

    /// Open a conditional. Outside skipped text its probes are scanned
    /// and its branch chosen; inside skipped text TeX pushes a passed
    /// conditional that merely balances to its `\fi`.
    fn open_cond(&mut self, kind: IfKind) -> Result<(), TeXError> {
        if self.skipped() {
            self.conds.push(CondState { kind, branch: BranchState::Locked, else_seen: false });
            return Ok(());
        }
        let branch = match kind {
            IfKind::True => BranchState::Selected,
            IfKind::False => BranchState::Dropping,
            IfKind::Char => {
                if self.if_char()? {
                    BranchState::Selected
                } else {
                    BranchState::Dropping
                }
            }
            IfKind::X => {
                if self.if_x()? {
                    BranchState::Selected
                } else {
                    BranchState::Dropping
                }
            }
            IfKind::Num => {
                if self.if_num()? {
                    BranchState::Selected
                } else {
                    BranchState::Dropping
                }
            }
            IfKind::Case => {
                let number = self.scan_number("\\ifcase")?;
                // Case n selects branch `n` (`\or` hops): n > 0 waits
                // that many `\or`s; n = 0 selects at once; n < 0
                // (TeX's empty read) suppresses every branch until the
                // `\else`/`\fi` (parity-vs-oracle delta recorded for
                // L6).
                match number {
                    0 => BranchState::Selected,
                    n if n > 0 => BranchState::Waiting(n),
                    _ => BranchState::Dropping,
                }
            }
        };
        self.conds.push(CondState { kind, branch, else_seen: false });
        Ok(())
    }

    /// `\if`: two tokens after full expansion, compared by character
    /// and category code.
    fn if_char(&mut self) -> Result<bool, TeXError> {
        let Some(Token::Char(x, cx)) = self.next_expanded()? else {
            return Err(TeXError::FileEnded { context: String::from("\\if") });
        };
        let Some(Token::Char(y, cy)) = self.next_expanded()? else {
            return Err(TeXError::FileEnded { context: String::from("\\if") });
        };
        Ok(x == y && cx == cy)
    }

    /// `\ifx`: two tokens without expansion; a control-sequence pair
    /// agrees on identical names, `\let`-copies, equal primitives, or
    /// two undefined meanings. Exact TeX corner parity is an L6 note.
    fn if_x(&mut self) -> Result<bool, TeXError> {
        let Some(a) = self.get_token() else {
            return Err(TeXError::FileEnded { context: String::from("\\ifx") });
        };
        let Some(b) = self.get_token() else {
            return Err(TeXError::FileEnded { context: String::from("\\ifx") });
        };
        match (&a, &b) {
            (Token::Cs(ca), Token::Cs(cb)) => {
                if ca.name == cb.name {
                    return Ok(true);
                }
                match (self.entry(&ca.name), self.entry(&cb.name)) {
                    (Some(CsEntry::Macro(x)), Some(CsEntry::Macro(y))) => Ok(Rc::ptr_eq(&x, &y)),
                    (Some(CsEntry::CharMeaning(x, cx)), Some(CsEntry::CharMeaning(y, cy))) => {
                        Ok(x == y && cx == cy)
                    }
                    (Some(CsEntry::Prim(x)), Some(CsEntry::Prim(y))) => Ok(x == y),
                    (a, b) => {
                        // Two undefined meanings agree (TeX's
                        // `\csname`-produced undefined cs); anything
                        // else differs.
                        let undefined_c = |e: Option<CsEntry>| {
                            matches!(e, Some(CsEntry::Undefined) | None)
                        };
                        Ok(undefined_c(a) && undefined_c(b))
                    }
                }
            }
            (Token::Char(x, cx), Token::Char(y, cy)) => Ok(x == y && cx == cy),
            _ => Ok(false),
        }
    }

    /// `\ifnum`: two integers and a comparison character.
    fn if_num(&mut self) -> Result<bool, TeXError> {
        let left = self.scan_number("\\ifnum")?;
        let Some(Token::Char(op, _)) = self.next_expanded()? else {
            return Err(TeXError::MissingNumber { context: String::from("\\ifnum") });
        };
        let order = match op {
            '=' => 0,
            '<' => -1,
            '>' => 1,
            _ => return Err(TeXError::MissingNumber { context: String::from("\\ifnum") }),
        };
        let right = self.scan_number("\\ifnum")?;
        Ok(match order {
            0 => left == right,
            -1 => left < right,
            _ => left > right,
        })
    }

    /// Whether the innermost conditional is locked (i.e. everything at
    /// this position balances to an outer skip): locked regions step
    /// their `\else`/`\or` without state effects.
    fn outer_locked(&self) -> bool {
        self.conds.last().is_some_and(|c| matches!(c.branch, BranchState::Locked))
    }

    /// An `\else` in a live branch: the branch flips to dropping (the
    /// `\else`'s text is skipped, whatever the conditional kind).
    fn saw_else(&mut self) -> Result<(), TeXError> {
        let Some(cond) = self.conds.last_mut() else {
            return Err(TeXError::ExtraElse);
        };
        if cond.else_seen || matches!(cond.branch, BranchState::Locked) {
            return Err(TeXError::ExtraElse);
        }
        cond.else_seen = true;
        cond.branch = BranchState::Dropping;
        Ok(())
    }

    /// An `\else` while skipping: non-`\ifcase` conditionals must
    /// resume flow at the `\else` text; a spent `\ifcase` stays
    /// dropping, and a second `\else` is still an error.
    fn saw_else_skipped(&mut self) -> Result<(), TeXError> {
        let Some(cond) = self.conds.last_mut() else {
            return Err(TeXError::ExtraElse);
        };
        if cond.else_seen || matches!(cond.branch, BranchState::Locked) {
            return Err(TeXError::ExtraElse);
        }
        cond.else_seen = true;
        if cond.kind != IfKind::Case {
            cond.branch = BranchState::Selected;
        } else {
            cond.branch = BranchState::Dropping;
        }
        Ok(())
    }

    /// An `\or`: legal only inside `\ifcase`, where it hops to the
    /// next case branch (`Waiting(n)` counts the `\or`s left; once the
    /// count is spent flow resumes; a selected branch's remaining
    /// branches drop); after a `\else`, or outside `\ifcase`, an error.
    fn saw_or(&mut self) -> Result<(), TeXError> {
        let Some(cond) = self.conds.last_mut() else {
            return Err(TeXError::ExtraOr);
        };
        if cond.kind != IfKind::Case {
            return Err(TeXError::ExtraOr);
        }
        if cond.else_seen {
            return Err(TeXError::ExtraOr);
        }
        cond.branch = match cond.branch {
            BranchState::Waiting(n) if n > 1 => BranchState::Waiting(n - 1),
            BranchState::Waiting(_) => BranchState::Selected,
            _ => BranchState::Dropping,
        };
        Ok(())
    }

    /// Route one token inside a skipped region: conditional bookkeeping
    /// keeps the nesting balanced, everything else drops without
    /// expansion. In locked (passed) regions TeX balances `\else`/`\or`
    /// silently — an L6 tuning note.
    fn route_skipped(&mut self, token: Token) -> Result<(), TeXError> {
        let Token::Cs(cs) = &token else {
            return Ok(());
        };
        let name = cs.name.clone();
        match self.entry(&name) {
            Some(CsEntry::Prim(Prim::If(kind))) => {
                self.conds.push(CondState { kind, branch: BranchState::Locked, else_seen: false });
            }
            Some(CsEntry::Prim(Prim::Else)) => {
                // A passed (locked) conditional balances silently; the
                // innermost live one resumes flow at the `\else` text
                // (unless `\ifcase` has run out of branches).
                if !self.outer_locked() {
                    self.saw_else_skipped()?;
                }
            }
            Some(CsEntry::Prim(Prim::Or)) => {
                if !self.outer_locked() {
                    self.saw_or()?;
                }
            }
            Some(CsEntry::Prim(Prim::Fi)) if self.conds.pop().is_none() => {
                return Err(TeXError::ExtraFi);
            }
            Some(CsEntry::Prim(Prim::Fi)) => {}
            _ => {}
        }
        Ok(())
    }

    /// Peek the next fully expanded token without consuming it.
    fn peek_expanded(&mut self) -> Result<Option<Token>, TeXError> {
        let Some(token) = self.next_expanded()? else {
            return Ok(None);
        };
        self.token_front(token.clone());
        Ok(Some(token))
    }

    /// Scan an integer (TeXbook ch. 24, minimal): optional signs and
    /// spaces, decimal digit coalescing, `\relax` tolerated before and
    /// after. Hex/octal constants (`'`, `"`), `\char`-equivalents and
    /// `\catcode`-read prim scans are L6 work.
    fn scan_number(&mut self, context: &str) -> Result<i64, TeXError> {
        let mut sign: i64 = 1;
        let mut value: u64 = 0;
        let mut had_digits = false;
        loop {
            let Some(token) = self.peek_expanded()? else {
                return Err(TeXError::FileEnded { context: context.to_string() });
            };
            match &token {
                Token::Char(d, CategoryCode::Other) if d.is_ascii_digit() => {
                    had_digits = true;
                    self.get_token();
                    let digit = u64::from(*d as u8 - b'0');
                    let Some(next) = value.checked_mul(10).and_then(|v| v.checked_add(digit)) else {
                        return Err(TeXError::NumberTooLarge);
                    };
                    value = next;
                }
                Token::Char(' ', _) if !had_digits => {
                    self.get_token();
                }
                Token::Char(c, _) if !had_digits && (*c == '+' || *c == '-') => {
                    self.get_token();
                    if *c == '-' {
                        sign = -sign;
                    }
                }
                Token::Cs(cs) => {
                    if self.is_relax(&cs.name) {
                        // `\relax` before the number is absorbed; after
                        // the digits it also terminates the scan.
                        self.get_token();
                        if had_digits {
                            break;
                        }
                    } else {
                        // A different control sequence ends the scan,
                        // left in place for the caller.
                        break;
                    }
                }
                // Anything else: leave it in place for the caller.
                _ => break,
            }
        }
        if !had_digits {
            return Err(TeXError::MissingNumber { context: context.to_string() });
        }
        // One optional space follows the integer (TeX's scan absorbs
        // it); it must be a catcode-10 space token.
        if let Some(Token::Char(' ', _)) = self.peek_expanded()? {
            self.get_token();
        }
        let magnitude = i64::try_from(value).map_err(|_| TeXError::NumberTooLarge)?;
        Ok(if sign < 0 { -magnitude } else { magnitude })
    }

    fn is_relax(&self, name: &str) -> bool {
        matches!(self.entry(name), Some(CsEntry::Prim(Prim::Relax)))
    }

    /// Close a group: restore its scoped definitions, in reverse.
    fn close_group(&mut self) -> Result<(), TeXError> {
        let Some(log) = self.groups.pop() else {
            return Err(TeXError::ExtraEndGroup);
        };
        undo_entries(self, log);
        Ok(())
    }
}

/// Restore a group's undo log: recorded entries re-bind, and
/// "never defined" names un-bind again.
fn undo_entries(expander: &mut Expander, log: Vec<(String, Option<CsEntry>)>) {
    for (name, entry) in log.into_iter().rev() {
        match entry {
            Some(entry) => expander.table.insert(name, entry),
            None => expander.table.remove(&name),
        };
    }
}

/// Whether the primitive expands at expansion level (vs. being routed
/// to the main processor).
fn prim_expands(p: Prim) -> bool {
    matches!(
        p,
        Prim::If(_)
            | Prim::Csxname
            | Prim::String
            | Prim::Meaning
            | Prim::Number
            | Prim::ExpandAfter
            | Prim::NoExpand
    )
}

/// `\number` output: the decimal digits (with a `-` when negative), all
/// catcode 12.
fn number_tokens(value: i64) -> Vec<Token> {
    format!("{value}")
        .chars()
        .map(|c| Token::Char(c, CategoryCode::Other))
        .collect()
}
