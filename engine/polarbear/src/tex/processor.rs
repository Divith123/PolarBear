// Copyright (c) 2026 Divith123. Licensed under the MIT License.

//! The main processor: a mode machine over fully expanded tokens.
//!
//! TeX's main loop alternates with expansion; here the expansion
//! processor ([`crate::tex::expand::Expander`]) runs first and hands
//! this machine a complete token stream — expanded, with group braces
//! turned into [`Token::GroupBegin`] / [`Token::GroupEnd`] markers so
//! box bodies can be seen. The machine's job is the same as tex.web's
//! main control at §1085: route each token to the right list by mode,
//! pack nodes as containers close, and end the run with the page's
//! vertical material for the writer.
//!
//! Modes: vertical (the page), horizontal (a paragraph), internal
//! horizontal/vertical (an `\hbox`/`\vbox`/`\vtop` body). Character
//! tokens start a paragraph from vertical mode; in integer-vertical
//! mode they raise [`TeXError::VerticalListChar`]. `\par` closes the
//! paragraph (one naturally packed hbox per paragraph — the line
//! breaker of a later slab replaces this when it exists); interline
//! glue is a fixed 12pt stub until the register layer grows.
//!
//! Dimension, integer and glue scanning follow tex.web's scan rules
//! (signs, decimals, unit letters, `plus`/`minus` parts) simplified to
//! what unexpanded typesetting material needs: no register references
//! or `\mag` yet, and fraction digits are capped at six places.

use crate::tex::catcode::CategoryCode;
use crate::tex::dim::{sum_sp, Scaled};
use crate::tex::expand::TeXError;
use crate::tex::nodes::{
    FontParam, GlueOrder, GlueSpec, MetricsSource, Node, PackRule, VBox,
};
use crate::tex::pack::{hpack, vpack, PackWarning};
use crate::tex::token::Token;

/// TeX's dimension ceiling: |value| must fit ±(2³⁰−1) sp.
const DIMEN_LIMIT: i64 = (1 << 30) - 1;
/// TeX's default rule thickness, 0.4pt (26214 sp) — the null-dimension
/// default for `\hrule`'s height and `\vrule`'s width.
const RULE_THICKNESS: Scaled = Scaled(26214);
/// TeX's dimension fraction reading caps at this many decimal places
/// (six covers everyday literals; L6 rounds true arithmetic).
const FRAC_PLACES_LIMIT: usize = 6;

/// Which container an open box frame packs into.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum FrameKind {
    /// `\hbox`.
    Horizontal,
    /// `\vtop`: packed like a vbox, then re-heighted to its first
    /// box/rule member.
    Top,
    /// `\vbox`.
    Vertical,
}

/// A box body open at some point of the mode machine.
struct Frame {
    kind: FrameKind,
    /// The `to`/`spread` rule recorded at the box header.
    rule: PackRule,
    list: Vec<Node>,
    /// Group markers of the box body that opened after the body's own
    /// marker (the body's opener leaves this at 0).
    nesting: usize,
}

/// One glue component scan: a size and its order of infinity.
#[derive(Clone, Copy, Debug)]
struct GluePart {
    size: Scaled,
    order: GlueOrder,
}

/// One unit of measurement, resolved from its letter run (tex.web's
/// unit table: the fractions are the ones Knuth stores).
enum Unit {
    /// A physical unit: (numerator, denominator) of a point.
    Physical(i64, i64),
    /// The scaled point (the value is its own sp amount).
    Sp,
    /// Fil glue, by ladder rank (fil/fill/filll).
    Fil(GlueOrder),
    /// The font's quad (`em`).
    Em,
    /// The font's x-height (`ex`).
    Ex,
}

/// The main processor.
pub struct Processor<'m> {
    /// Character metrics for packing (fonts arrive in L4).
    metrics: &'m mut dyn MetricsSource,
    /// Current font index for character nodes (stub 0 until `\font`).
    font: u16,
    /// The box header scanned but not yet owned by a body (its `{`).
    pending: Option<FrameKind>,
    /// The `to`/`spread` rule for the pending box.
    pending_rule: Option<PackRule>,
    /// Open box bodies, innermost last.
    stack: Vec<Frame>,
    /// The page's vertical material.
    page: Vec<Node>,
    /// An open paragraph's horizontal material.
    para: Vec<Node>,
    /// Whether a paragraph is running (external horizontal mode).
    para_open: bool,
    /// Packing reports (underfull/overfull/infinite-shrink) in order.
    pack_report: Vec<PackWarning>,
    /// The token stream under the pointer.
    tokens: Vec<Token>,
    /// Scanner position inside `tokens`.
    pos: usize,
    /// Set by `\end` to stop the run early.
    finished: bool,
}

impl<'m> Processor<'m> {
    /// A fresh processor over a metrics source.
    pub fn new(metrics: &'m mut dyn MetricsSource) -> Self {
        Self {
            metrics,
            font: 0,
            pending: None,
            pending_rule: None,
            stack: Vec::new(),
            page: Vec::new(),
            para: Vec::new(),
            para_open: false,
            pack_report: Vec::new(),
            tokens: Vec::new(),
            pos: 0,
            finished: false,
        }
    }

    /// Processes a fully expanded token stream and returns the page's
    /// vertical material (one page; the page breaker arrives in a
    /// later slab).
    ///
    /// # Errors
    /// [`TeXError`] for every mode-machine violation (undefined
    /// control sequence, illegal unit, wrong-mode token, missing
    /// number/brace) and anything the packer raises.
    pub fn run(&mut self, tokens: Vec<Token>) -> Result<Vec<Node>, TeXError> {
        self.tokens = tokens;
        self.pos = 0;
        while !self.finished {
            let Some(token) = self.tokens.get(self.pos) else {
                break;
            };
            let token = token.clone();
            self.pos += 1;
            self.step(token)?;
        }
        self.paragraph_end()?;
        Ok(std::mem::take(&mut self.page))
    }

    /// The packing report collected so far.
    #[must_use]
    pub fn pack_report(&self) -> &[PackWarning] {
        &self.pack_report
    }

    // ------------ dispatch ------------

    /// Routes one token by mode and container (tex.web §1085).
    fn step(&mut self, token: Token) -> Result<(), TeXError> {
        match token {
            Token::Cs(cs) => {
                if self.pending.is_some() {
                    // TeX's `Missing {` recovery: everything that is
                    // not the group open becomes body material.
                    self.recover_missing_body();
                }
                self.dispatch_cs(cs.name)
            }
            Token::Char(c, cat) => {
                if let CategoryCode::Space = cat {
                    if self.pending.is_some() {
                        // Spaces before a box opener's `{` are dropped.
                        return Ok(());
                    }
                } else if self.pending.is_some() {
                    self.recover_missing_body();
                }
                self.dispatch_char(c, cat)
            }
            Token::GroupBegin => {
                self.group_open();
                Ok(())
            }
            Token::GroupEnd => {
                self.group_close()?;
                Ok(())
            }
            Token::Parameter(_) => Err(self.not_in_mode("`#'")),
        }
    }

    /// Main-control primitives by name.
    fn dispatch_cs(&mut self, name: String) -> Result<(), TeXError> {
        match name.as_str() {
            "hbox" => self.open_box(FrameKind::Horizontal),
            "vbox" => self.open_box(FrameKind::Vertical),
            "vtop" => self.open_box(FrameKind::Top),
            "hskip" | "vskip" => {
                let glue = self.scan_glue(&name)?;
                self.contribute(Node::Glue(glue))
            }
            "kern" => {
                let size = self.scan_dimen("kern")?;
                self.contribute(Node::Kern(size))
            }
            "penalty" => {
                let n = self.scan_int("penalty")?;
                self.contribute(Node::Penalty(n))
            }
            "char" => {
                let n = self.scan_int("char")?;
                // Character codes stop at 255 (tex.web's invalid-code
                // check; TeX recovers by using 0).
                if n > 255 {
                    return Err(TeXError::NumberTooLarge);
                }
                self.contribute(Node::Char { font: self.font, code: n.max(0) as u32 })
            }
            "hrule" | "vrule" => self.open_rule(&name),
            "par" => {
                // `\par` in vertical mode does nothing.
                if self.para_open {
                    self.paragraph_end()?;
                }
                Ok(())
            }
            "end" => {
                self.paragraph_end()?;
                self.finished = true;
                Ok(())
            }
            "relax" => Ok(()),
            // Control space behaves as a character token space
            // (tex.web §): interword glue in horizontal material,
            // nothing on the page.
            " " => self.dispatch_char(' ', CategoryCode::Space),
            _ => Err(TeXError::UndefinedCs { name }),
        }
    }

    /// Character tokens by category: letters/other typeset, spaces
    /// become interword glue in horizontal material, group braces are
    /// impossible here (markers replaced them), and the math/alignment
    /// families reach the processor only through broken input at this
    /// layer.
    fn dispatch_char(&mut self, c: char, cat: CategoryCode) -> Result<(), TeXError> {
        match cat {
            CategoryCode::BeginGroup => {
                self.group_open();
                Ok(())
            }
            CategoryCode::EndGroup => self.group_close(),
            CategoryCode::Space => {
                if self.stack.last().is_some() || self.para_open {
                    let glue = self.metrics.font_glue(self.font, FontParam::Space)?;
                    self.contribute(Node::Glue(glue))
                } else {
                    // Spaces on the page contribute nothing (TeX's
                    // vertical-mode spacer discipline).
                    Ok(())
                }
            }
            CategoryCode::Letter | CategoryCode::Other => {
                let node = Node::Char { font: self.font, code: c as u32 };
                self.contribute_char(node)
            }
            CategoryCode::MathShift
            | CategoryCode::AlignmentTab
            | CategoryCode::Escape
            | CategoryCode::EndOfLine
            | CategoryCode::Parameter
            | CategoryCode::Superscript
            | CategoryCode::Subscript
            | CategoryCode::Ignored
            | CategoryCode::Active
            | CategoryCode::Comment
            | CategoryCode::Invalid => Err(self.not_in_mode(&format!("`{c}'"))),
        }
    }

    // ------------ groups ------------

    /// A group open: the box body's marker consumes a pending box
    /// header, a body's own braces just nest.
    fn group_open(&mut self) {
        if let Some(kind) = self.pending.take() {
            let rule = self.pending_rule.take().unwrap_or(PackRule::Natural);
            self.stack.push(Frame { kind, rule, list: Vec::new(), nesting: 0 });
        } else if let Some(frame) = self.stack.last_mut() {
            frame.nesting += 1;
        }
        // Braces on the page or inside a paragraph carry no container
        // semantics at this layer; the expander did the scoping.
    }

    /// A group close: closes the innermost box when its own marker
    /// returns, drops the nesting depth otherwise.
    fn group_close(&mut self) -> Result<(), TeXError> {
        let close = match self.stack.last_mut() {
            None => false,
            Some(frame) => {
                if frame.nesting == 0 {
                    true
                } else {
                    frame.nesting -= 1;
                    false
                }
            }
        };
        if close {
            self.close_frame()?;
        }
        Ok(())
    }

    // ------------ contributions ------------

    /// A typeset character: starts a paragraph from vertical mode,
    /// errors in integer-vertical mode, otherwise contributes.
    fn contribute_char(&mut self, node: Node) -> Result<(), TeXError> {
        if self.in_internal_vertical() {
            return Err(TeXError::VerticalListChar);
        }
        if self.stack.last().is_none() && !self.para_open {
            // A character from vertical mode starts a paragraph (TeX's
            // new-par signal; the paragraph indent glue is format
            // work).
            self.para_open = true;
        }
        self.contribute(node)
    }

    /// Whether the current mode is integer vertical (a character there
    /// is TeX's error).
    fn in_internal_vertical(&self) -> bool {
        matches!(
            self.stack.last().map(|frame| frame.kind),
            Some(FrameKind::Vertical | FrameKind::Top)
        )
    }

    /// TeX's wrong-mode message wording for the error variant.
    fn not_in_mode(&self, what: &str) -> TeXError {
        let mode = match self.stack.last() {
            None => if self.para_open { "horizontal mode" } else { "vertical mode" },
            Some(frame) => match frame.kind {
                FrameKind::Horizontal => "internal horizontal mode",
                FrameKind::Vertical | FrameKind::Top => "internal vertical mode",
            },
        };
        TeXError::NotInMode { what: what.to_string(), mode }
    }

    /// Pushes a node into whatever container owns the material: an
    /// open box, else the under-construction paragraph, else the page.
    fn contribute(&mut self, node: Node) -> Result<(), TeXError> {
        if let Some(frame) = self.stack.last_mut() {
            frame.list.push(node);
            return Ok(());
        }
        if self.para_open {
            self.para.push(node);
            return Ok(());
        }
        self.page.push(node);
        Ok(())
    }

    /// Ends the running paragraph: one naturally packed hbox, then the
    /// interline glue stub (the register layer replaces both when it
    /// lands). Nothing is emitted for an empty paragraph.
    fn paragraph_end(&mut self) -> Result<(), TeXError> {
        if !self.para_open {
            return Ok(());
        }
        self.para_open = false;
        let paragraph = std::mem::take(&mut self.para);
        if !paragraph.is_empty() {
            let lane = hpack(
                paragraph,
                PackRule::Natural,
                &mut *self.metrics,
                &mut self.pack_report,
            )?;
            self.page.push(Node::HBox(Box::new(lane)));
            self.page.push(Node::Glue(GlueSpec::finite(Scaled(12 * 65_536))));
        }
        Ok(())
    }

    // ------------ boxes ------------

    /// Pushes the pending box body early — tex.web's `Missing {`
    /// inserted recovery: the offending token becomes body material.
    fn recover_missing_body(&mut self) {
        let Some(kind) = self.pending.take() else {
            return;
        };
        let rule = self.pending_rule.take().unwrap_or(PackRule::Natural);
        self.stack.push(Frame { kind, rule, list: Vec::new(), nesting: 0 });
    }

    /// `\hbox`/`\vbox`/`\vtop` header: optional `to`/`spread` rule,
    /// then the body starts with a group open (spaces before it drop).
    /// The keywords are letter runs, not control sequences — TeX's
    /// box processor sees letter tokens (that is why a `\to` macro
    /// redefinition cannot shadow them).
    fn open_box(&mut self, kind: FrameKind) -> Result<(), TeXError> {
        self.skip_spaces();
        let rule = if self.keyword("to") {
            let size = self.scan_dimen("to")?;
            PackRule::To(size)
        } else if self.keyword("spread") {
            let size = self.scan_dimen("spread")?;
            PackRule::Spread(size)
        } else {
            PackRule::Natural
        };
        self.pending = Some(kind);
        self.pending_rule = Some(rule);
        Ok(())
    }

    /// Closes the innermost box: packs it, re-heights `\vtop`s, and
    /// contributes the node to the parent material.
    fn close_frame(&mut self) -> Result<(), TeXError> {
        let Some(frame) = self.stack.pop() else {
            return Ok(());
        };
        let node = match frame.kind {
            FrameKind::Horizontal => {
                let lane = hpack(
                    frame.list,
                    frame.rule,
                    &mut *self.metrics,
                    &mut self.pack_report,
                )?;
                Node::HBox(Box::new(lane))
            }
            FrameKind::Vertical | FrameKind::Top => {
                let mut column = vpack(frame.list, frame.rule, &mut self.pack_report)?;
                if frame.kind == FrameKind::Top {
                    reheight_top(&mut column);
                }
                Node::VBox(Box::new(column))
            }
        };
        self.contribute(node)
    }

    /// `\hrule`/`\vrule`: the wrong-direction rule is TeX's mode
    /// error; unwritten height (hrule) or width (vrule) defaults to
    /// 0.4pt, unwritten sides stay null (probe-verified:
    /// `\vbox{\hrule}` ⇒ rule (0.4+0.0)x* with a 0-wide box,
    /// `\hbox{\vrule}` ⇒ (*+*)x0.4).
    fn open_rule(&mut self, name: &str) -> Result<(), TeXError> {
        let hrule = name == "hrule";
        let mode_ok = match self.stack.last().map(|frame| frame.kind) {
            None => !self.para_open || !hrule,
            Some(FrameKind::Vertical | FrameKind::Top) => hrule,
            Some(FrameKind::Horizontal) => !hrule,
        };
        if !mode_ok {
            let mode = if hrule { "horizontal mode" } else { "vertical mode" };
            return Err(TeXError::NotInMode {
                what: format!("`\\{name}'"),
                mode,
            });
        }
        let mut width: Option<Scaled> = None;
        let mut height: Option<Scaled> = None;
        let mut depth: Option<Scaled> = None;
        loop {
            self.skip_spaces();
            let side = if self.keyword("width") {
                &mut width
            } else if self.keyword("height") {
                &mut height
            } else if self.keyword("depth") {
                &mut depth
            } else {
                break;
            };
            let size = self.scan_dimen(&format!("\\{name}"))?;
            *side = Some(size);
        }
        let (width, height, depth) = if hrule {
            (width, height.or(Some(RULE_THICKNESS)), depth.or(Some(Scaled(0))))
        } else {
            (width.or(Some(RULE_THICKNESS)), height, depth)
        };
        self.contribute(Node::Rule { width, height, depth })
    }

    // ------------ scanning ------------

    /// The scanned char under the pointer, without consuming.
    fn peek_char(&self) -> Option<(char, CategoryCode)> {
        match self.tokens.get(self.pos) {
            Some(Token::Char(c, cat)) => Some((*c, *cat)),
            _ => None,
        }
    }

    /// Drops cat-10 tokens.
    fn skip_spaces(&mut self) {
        while let Some((_, CategoryCode::Space)) = self.peek_char() {
            self.pos += 1;
        }
    }

    /// Optional signs as TeX's scanners take them: any run of `+`/`-`,
    /// flipping at each `-`.
    fn scan_sign(&mut self) -> i64 {
        let mut sign = 1;
        loop {
            match self.peek_char() {
                Some(('+', _)) => self.pos += 1,
                Some(('-', _)) => {
                    sign = -sign;
                    self.pos += 1;
                }
                _ => return sign,
            }
        }
    }

    /// Integer scan (tex.web's `scan_int` simplified): signs, plain
    /// digits, no register references. Spaces are skipped before the
    /// digits and after them (tex.web's optional-space margin).
    fn scan_int(&mut self, context: &str) -> Result<i32, TeXError> {
        self.skip_spaces();
        let sign = self.scan_sign();
        let mut value: i64 = 0;
        let mut seen = false;
        while let Some((c, _)) = self.peek_char() {
            let Some(d) = c.to_digit(10) else {
                break;
            };
            seen = true;
            self.pos += 1;
            value = value * 10 + i64::from(d);
            if value > i64::from(i32::MAX) {
                return Err(TeXError::NumberTooLarge);
            }
        }
        if !seen {
            return Err(TeXError::MissingNumber { context: context.to_string() });
        }
        self.skip_spaces();
        i32::try_from(sign * value).map_err(|_| TeXError::NumberTooLarge)
    }

    /// Reads the letter run that names a unit (one `true` prefix
    /// allowed), as tex.web's `scan_unit` sees them.
    fn scan_unit_letters(&mut self) -> String {
        fn collect(this: &mut Processor<'_>) -> String {
            let mut out = String::new();
            while let Some((c, CategoryCode::Letter)) = this.peek_char() {
                this.pos += 1;
                out.push(c);
                if out.len() > 8 {
                    break;
                }
            }
            out
        }
        let mut letters = collect(self);
        if let Some(stripped) = letters.strip_prefix("true") {
            letters = stripped.to_string();
            letters.push_str(&collect(self));
        }
        letters
    }

    /// Which unit the letter run names.
    fn unit_of(&self, letters: &str, context: &str) -> Result<Unit, TeXError> {
        match letters {
            "pt" => Ok(Unit::Physical(1, 1)),
            "mm" => Ok(Unit::Physical(36677, 10_000)),
            "cm" => Ok(Unit::Physical(7227, 254)),
            "in" => Ok(Unit::Physical(7227, 100)),
            "bp" => Ok(Unit::Physical(803, 800)),
            "pc" => Ok(Unit::Physical(12, 1)),
            "dd" => Ok(Unit::Physical(1238, 1157)),
            "cc" => Ok(Unit::Physical(1486, 1157)),
            "sp" => Ok(Unit::Sp),
            "em" => Ok(Unit::Em),
            "ex" => Ok(Unit::Ex),
            "fil" => Ok(Unit::Fil(GlueOrder::Fil)),
            "fill" => Ok(Unit::Fil(GlueOrder::Fill)),
            "filll" => Ok(Unit::Fil(GlueOrder::Filll)),
            _ => Err(TeXError::IllegalUnit { context: context.to_string() }),
        }
    }

    /// A font parameter in sp for unit arithmetic (tex.web §461: em and
    /// ex convert through the font's quad and x-height).
    fn font_param_scale(&mut self, param: FontParam) -> Result<i64, TeXError> {
        let glue = self.metrics.font_glue(self.font, param)?;
        Ok(i64::from(glue.width.0))
    }

    /// Multiplies a 2¹⁶-per-unit magnitude by a font parameter — the
    /// tex.web num/den conversion for `em`/`ex` (num = quad or
    /// x-height, den = 2¹⁶; rounding ties are an L6 byte-check point).
    fn unit_scale(&mut self, magnitude: i64, param: FontParam) -> Result<i64, TeXError> {
        let param_sp = self.font_param_scale(param)?;
        magnitude
            .checked_mul(param_sp)
            .and_then(|raw| raw.checked_add(32_768))
            .map(|raw| raw / 65_536)
            .ok_or(TeXError::DimensionTooLarge)
    }

    /// The digits scanned so far, scaled to the unit's meaning in
    /// points: the fractional part rounds per place-count (tex.web's
    /// fraction arithmetic; exact rounding forms are an L6 byte-check
    /// point). `em`/`ex` scale through the font's quad / x-height.
    fn finish_value(
        &mut self,
        value: i64,
        frac: i64,
        places: usize,
        unit: &Unit,
        negative: bool,
    ) -> Result<Scaled, TeXError> {
        let magnitude = value.abs().saturating_mul(65_536)
            + match places {
                0 => 0,
                _ => {
                    let den = 10_i64
                        .checked_pow(u32::try_from(places).unwrap_or(u32::MAX))
                        .unwrap_or(i64::MAX);
                    (frac * 65_536 + den / 2).saturating_div(den.max(1))
                }
            };
        let scaled = match unit {
            Unit::Sp => magnitude / 65_536,
            Unit::Physical(num, den) => (magnitude * num + den / 2) / den,
            Unit::Em => self.unit_scale(magnitude, FontParam::Quad)?,
            Unit::Ex => self.unit_scale(magnitude, FontParam::XHeight)?,
            Unit::Fil(_) => magnitude,
        };
        if scaled.abs() > DIMEN_LIMIT {
            return Err(TeXError::DimensionTooLarge);
        }
        let signed = if negative { -scaled } else { scaled };
        i32::try_from(signed).map(Scaled).map_err(|_| TeXError::DimensionTooLarge)
    }

    /// Digits with an optional decimal part; returns whether anything
    /// was seen. The cap keeps six fraction places, ignoring the rest
    /// (tex.web keeps counting; L6 byte-check point).
    fn scan_decimal(
        &mut self,
        value: &mut i64,
        frac: &mut i64,
        places: &mut usize,
    ) -> Result<bool, TeXError> {
        let mut seen = false;
        while let Some((c, _)) = self.peek_char() {
            let Some(d) = c.to_digit(10) else {
                break;
            };
            seen = true;
            self.pos += 1;
            *value = value
                .checked_mul(10)
                .and_then(|v| v.checked_add(i64::from(d)))
                .ok_or(TeXError::DimensionTooLarge)?;
        }
        if let Some(('.', _)) = self.peek_char() {
            seen = true;
            self.pos += 1;
            while let Some((c, _)) = self.peek_char() {
                let Some(d) = c.to_digit(10) else {
                    break;
                };
                self.pos += 1;
                if *places < FRAC_PLACES_LIMIT {
                    *frac = frac
                        .checked_mul(10)
                        .and_then(|v| v.checked_add(i64::from(d)))
                        .unwrap_or(*frac);
                    *places += 1;
                }
            }
        }
        Ok(seen)
    }

    /// Whole dimension scan: signs, `⟨digits⟩[.⟨digits⟩]`, unit run,
    /// trailing spaces dropped (tex.web's optional space after a
    /// complete dimension; the all-spaces margin is an L6 byte-check).
    fn scan_dimen(&mut self, context: &str) -> Result<Scaled, TeXError> {
        self.skip_spaces();
        let sign = self.scan_sign();
        let mut value = 0_i64;
        let mut frac = 0_i64;
        let mut places = 0_usize;
        if !self.scan_decimal(&mut value, &mut frac, &mut places)? {
            return Err(TeXError::MissingNumber { context: context.to_string() });
        }
        self.skip_spaces();
        let letters = self.scan_unit_letters();
        match self.unit_of(&letters, context)? {
            // A fil ladder on a plain dimension is TeX's illegal unit.
            Unit::Fil(_) => Err(TeXError::IllegalUnit { context: context.to_string() }),
            unit => self.finish_value(value, frac, places, &unit, sign < 0),
        }
    }

    /// One stretch/shrink part of a glue spec: a dimension whose unit
    /// may also be a fil ladder (tex.web's glue-scan arms).
    fn scan_glue_part(&mut self, name: &str) -> Result<GluePart, TeXError> {
        self.skip_spaces();
        let sign = self.scan_sign();
        let mut value = 0_i64;
        let mut frac = 0_i64;
        let mut places = 0_usize;
        if !self.scan_decimal(&mut value, &mut frac, &mut places)? {
            return Err(TeXError::MissingNumber { context: name.to_string() });
        }
        self.skip_spaces();
        let letters = self.scan_unit_letters();
        let unit = self.unit_of(&letters, name)?;
        let (order, size) = match unit {
            Unit::Fil(order) => (order, self.finish_value(value, frac, places, &unit, sign < 0)?),
            other => (GlueOrder::Finite, self.finish_value(value, frac, places, &other, sign < 0)?),
        };
        Ok(GluePart { size, order })
    }

    /// A `plus`/`minus` keyword: consumes the letter run when present,
    /// restores the scanner exactly where it started otherwise. This
    /// is safe here — every token is already materialized, so rolling
    /// the pointer back cannot replay an expansion.
    fn keyword(&mut self, want: &str) -> bool {
        let start = self.pos;
        self.skip_spaces();
        for expected in want.chars() {
            match self.peek_char() {
                Some((c, CategoryCode::Letter)) if c == expected => self.pos += 1,
                _ => {
                    self.pos = start;
                    return false;
                }
            }
        }
        if want.is_empty() {
            self.pos = start;
            return false;
        }
        true
    }

    /// Whole glue scan (`\hskip`/`\vskip`): the width, optional
    /// `plus`/`minus` parts.
    fn scan_glue(&mut self, name: &str) -> Result<GlueSpec, TeXError> {
        let width = self.scan_dimen(name)?;
        let mut glue = GlueSpec::finite(width);
        if self.keyword("plus") {
            let part = self.scan_glue_part(name)?;
            glue.stretch = part.size;
            glue.stretch_order = part.order;
        }
        if self.keyword("minus") {
            let part = self.scan_glue_part(name)?;
            glue.shrink = part.size;
            glue.shrink_order = part.order;
        }
        Ok(glue)
    }
}

/// `\vtop`: the box's height is its first box/rule member's height (or
/// 0) and the depth absorbs the difference. tex.web's `vtop`-lexeme
/// branch of the packer; an L6 byte-check point.
fn reheight_top(column: &mut VBox) {
    let first = column.list.iter().find_map(|member| match member {
        Node::HBox(inner) => Some(inner.height),
        Node::VBox(inner) => Some(inner.height),
        Node::Rule { height, .. } => *height,
        _ => None,
    });
    let old = column.height;
    column.height = first.unwrap_or(Scaled(0));
    if let Ok(delta) = sum_sp([old, Scaled(-column.height.0)]) {
        column.depth = sum_sp([column.depth, delta]).unwrap_or(column.depth);
    }
}
