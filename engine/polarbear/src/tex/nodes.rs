// Copyright (c) 2026 Divith123. Licensed under the MIT License.

//! The node graph — tex.web's main-memory typesetting structures
//! (texbook appendix; tex.web §§120–160 describe the dynamics, §§645–750
//! pack them into boxes).
//!
//! TeX is a box-and-glue machine: characters, rules, boxes, glue, kerns
//! and penalties flow into one shared node-list universe; horizontal
//! lists are packed into horizontal boxes, those into vertical lists,
//! and pages are vertical lists whose size the page builder drives.
//! Here the dynamic memory (mem words half-rings and node pools) is
//! expressed directly as a [`Node`] enum owning its children, with the
//! same semantics and the same names as tex.web's fields.
//!
//! The one structural simplification (recorded for L6): tex.web builds
//! boxes bottom-up and frees them into an avail pool; node ownership in
//! Rust gives the same observable behaviour — the *restored* layout of
//! packed lists, the widths, the orders of infinity — with the allocator
//! bookkeeping invisible.

use crate::tex::dim::Scaled;
use crate::tex::expand::TeXError;

/// An order of infinities for stretchable or shrinkable glue. `0` is
/// ordinary finite glue ("1with pt"); 1–3 are `fil`, `fill`, `filll`
/// — each order of infinity dominates every lower one, exactly as the
/// TeXbook's exercise 12.5 says.
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq, PartialOrd, Ord)]
pub enum GlueOrder {
    /// Finite stretch/shrink measured in `pt`.
    #[default]
    Finite,
    /// `fil` — one order of infinity.
    Fil,
    /// `fill` — two orders.
    Fill,
    /// `filll` — three orders (rare; compiled for completeness).
    Filll,
}

/// A glue specification: the natural size and the stretch/shrink parts
/// (tex.web's glue_node: width, stretch + stretch_order, shrink +
/// shrink_order).
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub struct GlueSpec {
    /// Natural width in `sp`.
    pub width: Scaled,
    /// Stretch amount; its unit is set by [`GlueSpec::stretch_order`].
    pub stretch: Scaled,
    /// The order of infinity of the stretch part.
    pub stretch_order: GlueOrder,
    /// Shrink amount; its unit is set by [`GlueSpec::shrink_order`].
    pub shrink: Scaled,
    /// The order of infinity of the shrink part.
    pub shrink_order: GlueOrder,
}

impl GlueSpec {
    /// A finite glue of the given natural width, zero stretch/shrink —
    /// tex.web's `zero_glue` for width, and what `\hskip ⟨dimen⟩`
    /// builds.
    pub fn finite(width: Scaled) -> Self {
        GlueSpec { width, ..GlueSpec::default() }
    }
}

/// How a packed box will distribute its excess/deficit space over glue:
/// tex.web's `glue_sign` + `glue_order` (§649). The fraction itself
/// lives on the box as `glue_set`.
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub enum GlueSetting {
    /// The natural size matched the wanted size exactly (sign `none`).
    #[default]
    Exactly,
    /// Glue stretches; the fraction distributes over glue of this order.
    Stretch(GlueOrder),
    /// Glue shrinks; the fraction distributes over glue of this order.
    Shrink(GlueOrder),
}

impl GlueSetting {
    /// tex.web's glue_sign: `none/stretching/shrinking`.
    pub fn sign(self) -> u8 {
        match self {
            GlueSetting::Exactly => 0,
            GlueSetting::Stretch(_) => 1,
            GlueSetting::Shrink(_) => 2,
        }
    }

    /// tex.web's glue_order (0–3), zero when the setting is exact.
    pub fn order(self) -> u8 {
        match self {
            GlueSetting::Exactly => 0,
            GlueSetting::Stretch(order) | GlueSetting::Shrink(order) => order as u8,
        }
    }
}

/// How a box is packed: tex.web's `additional`/`exactly` packing
/// distinction (§646) expressed as the rule the caller wrote.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum PackRule {
    /// The box's size comes from the material.
    Natural,
    /// The box is forced to the given width (`to ⟨dimen⟩`).
    To(Scaled),
    /// The box is spread to the given width (`spread ⟨dimen⟩`).
    Spread(Scaled),
}

/// One node of the shared node universe (a `halfword` in tex.web). Some
/// kinds exist only naturally in horizontal lists (characters); some
/// only in vertical lists (inserts); the shared ones appear in both.
#[derive(Clone, Debug, PartialEq)]
pub enum Node {
    /// A character to be typeset: font (an index into the font table
    /// that L4 fills) and the character code. Widths, heights and
    /// depths come from the font metrics source.
    Char {
        /// The font table index (tex.web's `font` halfword).
        font: u16,
        /// The character code (`ascii` halfword).
        code: u32,
    },
    /// Horizontal glue.
    Glue(GlueSpec),
    /// A kern: rigid spacing that breaks lines are made of.
    Kern(Scaled),
    /// A penalty node; line/page breaking uses its number.
    Penalty(i32),
    /// A discretionary: the pre-, post- and replacement texts of a
    /// break; the hyphenation machinery grows this.
    Disc {
        /// Text typeset before the break point.
        pre: Vec<Node>,
        /// Text typeset after the break.
        post: Vec<Node>,
        /// Text replacing the whole discretion when it closes.
        replace: Vec<Node>,
    },
    /// A packed horizontal box (tex.web's hlist_node with subtype 0).
    HBox(Box<HBox>),
    /// A packed vertical box (tex.web's hlist_node with subtype 1).
    VBox(Box<VBox>),
    /// A rule with fixed dimensions; `None` runs mean "the size of the
    /// enclosing box" (tex.web's null-dimension rules).
    Rule {
        /// Rule width; `None` inherits the box width.
        width: Option<Scaled>,
        /// Rule height; `None` inherits the box height.
        height: Option<Scaled>,
        /// Rule depth; `None` inherits the box depth.
        depth: Option<Scaled>,
    },
    /// A whatsit placeholder — extension hooks (`\mark`, `\write`,
    /// `\special`, `\insert`) land here in later slabs.
    Whatsit(u8),
}

/// A packed horizontal box: its dimensions, the shift written outside,
/// and the material.
#[derive(Clone, Debug, PartialEq)]
pub struct HBox {
    /// Width of the box.
    pub width: Scaled,
    /// Height of the box (below the baseline).
    pub height: Scaled,
    /// Depth of the box (below the baseline).
    pub depth: Scaled,
    /// Horizontal shift applied at the placement site (tex.web's
    /// `shift_amount` — vertical in horizontal mode).
    pub shift: Scaled,
    /// Glue-distribution decision recorded by the packing pass.
    pub glue_setting: GlueSetting,
    /// The fraction of the selected glue actually applied — fixed-point
    /// with 2¹⁶ = 1.0 (tex.web's `glue_set` ratio, scaled for exactness).
    pub glue_set: u32,
    /// The material.
    pub list: Vec<Node>,
}

/// A packed vertical box: same bookkeeping mirrored vertically.
#[derive(Clone, Debug, PartialEq)]
pub struct VBox {
    /// Width (max of the material's widths unless the packing file
    /// says otherwise).
    pub width: Scaled,
    /// Height of the box.
    pub height: Scaled,
    /// Depth of the box.
    pub depth: Scaled,
    /// Horizontal shift applied at the placement site.
    pub shift: Scaled,
    /// Glue-distribution decision recorded by the packing pass.
    pub glue_setting: GlueSetting,
    /// The fraction of the selected glue actually applied (fixed-point
    /// 2¹⁶ = 1.0).
    pub glue_set: u32,
    /// The material.
    pub list: Vec<Node>,
}

impl HBox {
    /// The default empty box — tex.web's `new_null_box`.
    pub fn new() -> Self {
        HBox {
            width: Scaled(0),
            height: Scaled(0),
            depth: Scaled(0),
            shift: Scaled(0),
            glue_setting: GlueSetting::Exactly,
            glue_set: 0,
            list: Vec::new(),
        }
    }
}

impl Default for HBox {
    fn default() -> Self {
        Self::new()
    }
}

impl VBox {
    /// The default empty box, mirrored.
    pub fn new() -> Self {
        VBox {
            width: Scaled(0),
            height: Scaled(0),
            depth: Scaled(0),
            shift: Scaled(0),
            glue_setting: GlueSetting::Exactly,
            glue_set: 0,
            list: Vec::new(),
        }
    }
}

impl Default for VBox {
    fn default() -> Self {
        VBox::new()
    }
}

/// The metrics a packed character can consult. L3 defines the shape and
/// a fallback stub; L4 replaces the stub with the real TFM/font-file
/// reader. Keeping it as a trait object means every packing/breaking
/// routine stays font-agnostic — TeX's font tables are runtime data.
pub trait MetricsSource {
    /// The (width, height, depth) of a character in a font. Unknown
    /// characters report the error-value triple tex.web's
    /// `font_info` lookup reports; the caller decides how loudly.
    fn char_dims(&mut self, font: u16, code: u32) -> Result<(Scaled, Scaled, Scaled), TeXError>;

    /// A parameter of a font (tex.web's `font_info[k]`); the plain glue
    /// ops (space, stretch, shrink, x-height, baselinekick) are the
    /// shared subset.
    fn font_glue(&mut self, font: u16, param: FontParam) -> Result<GlueSpec, TeXError>;
}

/// The font parameters the L3 machinery reads directly (tex.web
/// §624–634 list the full set; only the ones the main-processor core in
/// L3 needs are named).
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum FontParam {
    /// The interword space of the font.
    Space,
    /// Its stretch.
    Stretch,
    /// Its shrink.
    Shrink,
    /// The x-height of the font (the math-axis reference).
    XHeight,
    /// The quad (`\quad`).
    Quad,
}
