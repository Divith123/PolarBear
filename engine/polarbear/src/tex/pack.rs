// Copyright (c) 2026 Divith123. Licensed under the MIT License.

//! Packing — hpack and vpack (tex.web §§645–750).
//!
//! A horizontal list is turned into a box: the natural size accumulates
//! the material's widths (tallest height, deepest depth), glue stretch
//! and shrink are totalled per order of infinity, and a packing rule
//! distributes the difference over glue with tex.web's fractions and
//! the famous badness formula (§108). The vertical pass mirrors it:
//! heights roll forward with each member's depth, the box's depth is
//! the depth of the last box or rule, and the width grows to the widest
//! shifted member.
//!
//! Glue-setting details kept faithful to tex.web §649: infinite glue
//! dominates finite glue on stretch, but *only* the chosen bucket
//! shrinks; an infinite shrink order asked to soak up a deficit
//! surfaces tex.web's `Infinite glue shrinkage found` message, and
//! `spread` packing never warns (only `to` packing reports badness).

use crate::tex::dim::{from_64, sum_sp, Scaled};
use crate::tex::expand::TeXError;
use crate::tex::nodes::{
    GlueOrder, GlueSetting, GlueSpec, HBox, MetricsSource, Node, PackRule, VBox,
};

/// A packing-pass report tex.web would print: underfull/overfull boxes
/// and the infinite-shrinkage note. These are warnings in TeX, not
/// aborts; the caller decides how loud they are.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum PackWarning {
    /// `Underfull \hbox` / `\vbox`: stretching could not reach the
    /// target with badness ≤ 100.
    Underfull {
        /// The computed badness (0…10000).
        badness: i32,
    },
    /// `Overfull \hbox` / `\vbox`: the material is larger than the
    /// target even after full shrink; this is the overshoot amount.
    Overfull {
        /// How much the material overflows the wanted size.
        amount: Scaled,
    },
    /// tex.web's `Infinite glue shrinkage found`: the only available
    /// shrink is infinite while a finite-size job had to finish. The
    /// recorded setting is the notable `fil` fraction 1.
    InfiniteShrink,
}

/// The four-bucket stretch/shrink totals tex.web keeps while scanning a
/// list (§647: one per order of infinity).
#[derive(Clone, Copy, Debug, Default)]
struct GlueTotals {
    /// Stretch sum per order, finite bucket first.
    stretch: [Scaled; 4],
    /// Shrink sum per order, finite bucket first.
    shrink: [Scaled; 4],
}

impl GlueTotals {
    /// Adds one glue node.
    fn add(&mut self, glue: &GlueSpec) -> Result<(), TeXError> {
        let index = glue.stretch_order as usize;
        self.stretch[index] = sum_sp([self.stretch[index], glue.stretch])?;
        let index = glue.shrink_order as usize;
        self.shrink[index] = sum_sp([self.shrink[index], glue.shrink])?;
        Ok(())
    }

    /// The highest order of infinity whose stretch bucket is non-zero,
    /// scanning infinite orders first (tex.web's bucket choice at
    /// packing time, §649).
    fn stretch_bucket(&self) -> Option<(GlueOrder, Scaled)> {
        for order in (1..=3).rev() {
            if self.stretch[order].0 != 0 {
                return Some((Self::order_of(order), self.stretch[order]));
            }
        }
        if self.stretch[0].0 != 0 {
            return Some((GlueOrder::Finite, self.stretch[0]));
        }
        None
    }

    /// The same scan for shrink.
    fn shrink_bucket(&self) -> Option<(GlueOrder, Scaled)> {
        for order in (1..=3).rev() {
            if self.shrink[order].0 != 0 {
                return Some((Self::order_of(order), self.shrink[order]));
            }
        }
        if self.shrink[0].0 != 0 {
            return Some((GlueOrder::Finite, self.shrink[0]));
        }
        None
    }

    /// Array index back to the order enum.
    fn order_of(order: usize) -> GlueOrder {
        match order {
            1 => GlueOrder::Fil,
            2 => GlueOrder::Fill,
            _ => GlueOrder::Filll,
        }
    }
}

/// tex.web §108's badness function: the approximation
/// `⌊100·(100·t/s)³/1000⌋` computed with exact-integer pivots — the
/// constants 297, 1663497, 7230584 and the `>1290` clamp are tex.web's
/// own, so every badness value matches TeX's table.
pub fn badness(t: Scaled, s: Scaled) -> i32 {
    if t.0 == 0 {
        return 0;
    }
    if s.0 <= 0 {
        // `inf_bad + 1` — impermissible shrink.
        return 10001;
    }
    let t64 = t.0 as i64;
    let s64 = s.0 as i64;
    let r: i64 = if t64 <= 7230584 {
        t64 * 297 / s64
    } else if s64 >= 1663497 {
        t64 / (s64 / 297)
    } else {
        t64
    };
    if r > 1290 {
        return 10000;
    }
    // `(r³ + 2¹⁷) >> 18` — tex.web's rounding touch (a half towards
    // the next integer, so the raw ⌊100·t³/s³⌋ table comes out).
    ((r * r * r + (1 << 17)) >> 18) as i32
}

/// The horizontal scan (tex.web §647): widths accumulate characters
/// (through the metrics source), glue, kerns and boxes; the height and
/// depth grow to the tallest/deepest member, shifted by each box's
/// shift amount.
fn scan_h(
    list: &[Node],
    metrics: &mut dyn MetricsSource,
) -> Result<ScanH, TeXError> {
    let mut scan = ScanH::default();
    for node in list {
        match node {
            Node::Char { font, code } => {
                let (w, h, d) = metrics.char_dims(*font, *code)?;
                scan.width = sum_sp([scan.width, w])?;
                if scan.height.0 < h.0 {
                    scan.height = h;
                }
                if scan.depth.0 < d.0 {
                    scan.depth = d;
                }
            }
            Node::Glue(glue) => {
                scan.width = sum_sp([scan.width, glue.width])?;
                scan.totals.add(glue)?;
            }
            Node::Kern(kern) => {
                scan.width = sum_sp([scan.width, *kern])?;
            }
            Node::Penalty(_) | Node::Whatsit(_) => {}
            Node::Disc { replace, .. } => {
                // tex.web measures a disc by its replace text; the
                // replace list also never updates the box's height or
                // depth.
                let nested = scan_h(replace, metrics)?;
                scan.width = sum_sp([scan.width, nested.width])?;
            }
            Node::HBox(boxed) => {
                scan.width = sum_sp([scan.width, boxed.width])?;
                let raised = sum_sp([boxed.height, Scaled(-boxed.shift.0)])?;
                if scan.height.0 < raised.0 {
                    scan.height = raised;
                }
                let sunk = sum_sp([boxed.depth, boxed.shift])?;
                if scan.depth.0 < sunk.0 {
                    scan.depth = sunk;
                }
            }
            Node::VBox(boxed) => {
                scan.width = sum_sp([scan.width, boxed.width])?;
                let raised = sum_sp([boxed.height, Scaled(-boxed.shift.0)])?;
                if scan.height.0 < raised.0 {
                    scan.height = raised;
                }
                let sunk = sum_sp([boxed.depth, boxed.shift])?;
                if scan.depth.0 < sunk.0 {
                    scan.depth = sunk;
                }
            }
            Node::Rule { width, height, depth } => {
                // tex.web §647: a null-dimension side contributes
                // nothing measurable; an explicit dim does (the probe:
                // \vbox to 5pt{\hrule} keeps the rule at its 0.4pt
                // scan default and the box width at 0, while
                // \hbox to 10pt{...\vrule height 3pt...} takes the
                // rule's 3pt as the box height).
                scan.width = sum_sp([scan.width, width.unwrap_or(Scaled(0))])?;
                if let Some(h) = height {
                    if scan.height.0 < h.0 {
                        scan.height = *h;
                    }
                }
                if let Some(d) = depth {
                    if scan.depth.0 < d.0 {
                        scan.depth = *d;
                    }
                }
            }
        }
    }
    Ok(scan)
}

/// The horizontal measure result.
#[derive(Clone, Copy, Debug, Default)]
struct ScanH {
    /// Natural width.
    width: Scaled,
    /// Tallest height (below the baseline).
    height: Scaled,
    /// Deepest depth.
    depth: Scaled,
    /// Glue totals.
    totals: GlueTotals,
}

/// One measured member of a vertical list (tex.web §668's scan).
enum VMember {
    /// A box or rule, contributing the rolled height and depth.
    Item {
        /// Member width (with its shift applied).
        width: Scaled,
        /// Member height.
        height: Scaled,
        /// Member depth.
        depth: Scaled,
    },
    /// Vertical glue.
    Glue(GlueSpec),
    /// A vertical kern — tex.web §672: height rolls
    /// `h + depth + kern` and the depth stays (consecutive kerns each
    /// re-absorb the pending depth; marked as an L6 byte-check point).
    Kern(Scaled),
    /// Penalties/whatsits add nothing to the measurement.
    Skip,
}

/// The vertical measure pass (tex.web §668). A null-dimension rule
/// side measures as zero (the probe: `\vbox{\hrule}` gives a box of
/// width 0 with the rule at its own 0.4pt scan-time height; a null
/// width never spans). The drawn span of null-dimension rules is the
/// ship-out renderer's business, not the packer's.
fn measure_v(list: &[Node]) -> Result<Vec<VMember>, TeXError> {
    let mut members: Vec<VMember> = Vec::new();
    for node in list {
        match node {
            Node::Char { .. } => return Err(TeXError::VerticalListChar),
            Node::Disc { .. } => return Err(TeXError::VerticalListChar),
            Node::Glue(glue) => {
                members.push(VMember::Glue(*glue));
            }
            Node::Kern(kern) => {
                members.push(VMember::Kern(*kern));
            }
            Node::Penalty(_) | Node::Whatsit(_) => {
                members.push(VMember::Skip);
            }
            Node::HBox(boxed) => {
                // tex.web §673: re-anchoring symmetric both ways — the
                // box's height gives its top edge, the depth its
                // bottom, both shifted.
                let width = sum_sp([boxed.width, boxed.shift])?;
                members.push(VMember::Item {
                    width,
                    height: sum_sp([boxed.height, Scaled(-boxed.shift.0)])?,
                    depth: sum_sp([boxed.depth, boxed.shift])?,
                });
            }
            Node::VBox(boxed) => {
                let width = sum_sp([boxed.width, boxed.shift])?;
                members.push(VMember::Item {
                    width,
                    height: sum_sp([boxed.height, Scaled(-boxed.shift.0)])?,
                    depth: sum_sp([boxed.depth, boxed.shift])?,
                });
            }
            Node::Rule {
                width,
                height,
                depth,
            } => {
                members.push(VMember::Item {
                    width: width.unwrap_or(Scaled(0)),
                    height: height.unwrap_or(Scaled(0)),
                    depth: depth.unwrap_or(Scaled(0)),
                });
            }
        }
    }
    // The widest member comes out of the vpack roll itself.
    Ok(members)
}

/// Applies the packing rule after measurement: tex.web §649's
/// bucket choice, fraction math, and badness warnings.
fn set_glue(
    natural: Scaled,
    want: Scaled,
    suppress_warnings: bool,
    totals: &GlueTotals,
    warnings: &mut Vec<PackWarning>,
) -> Result<(GlueSetting, u32), TeXError> {
    let excess = sum_sp([want, Scaled(-natural.0)])?;
    if excess.0 == 0 {
        return Ok((GlueSetting::Exactly, 0));
    }
    if excess.0 > 0 {
        let Some((order, total)) = totals.stretch_bucket() else {
            if !suppress_warnings {
                warnings.push(PackWarning::Underfull { badness: 10000 });
            }
            // tex.web's degenerate case: nothing to stretch with; the
            // recorded setting stretches `fil` by the full fraction.
            return Ok((GlueSetting::Stretch(GlueOrder::Fil), 65_536));
        };
        let ratio = ratio_of(excess, total);
        if !suppress_warnings && badness(excess, total) > 100 {
            warnings.push(PackWarning::Underfull { badness: badness(excess, total) });
        }
        return Ok((GlueSetting::Stretch(order), ratio));
    }
    let deficit = from_64(-(excess.0 as i64))?;
    let Some((order, total)) = totals.shrink_bucket() else {
        if !suppress_warnings {
            warnings.push(PackWarning::Overfull { amount: deficit });
        }
        return Ok((GlueSetting::Exactly, 0));
    };
    if order != GlueOrder::Finite {
        if !suppress_warnings {
            warnings.push(PackWarning::InfiniteShrink);
        }
        return Ok((GlueSetting::Shrink(order), 65_536));
    }
    let ratio = ratio_of(deficit, total);
    if deficit.0 > total.0 && !suppress_warnings {
        warnings.push(PackWarning::Overfull {
            amount: Scaled(deficit.0 - total.0),
        });
    }
    Ok((GlueSetting::Shrink(order), ratio))
}

/// excess/total as a 2¹⁶ fraction (tex.web's glue_set, scaled 65536).
fn ratio_of(excess: Scaled, total: Scaled) -> u32 {
    let ratio = excess.0 as i64 * 65_536 / total.0 as i64;
    u32::try_from(ratio).unwrap_or(65_536)
}

/// Packs the list into a horizontal box (tex.web's `hpack`): natural
/// packing measures only; `to` forces a width and drops the report;
/// `spread` grows the glue by the want and never warns.
pub fn hpack(
    list: Vec<Node>,
    rule: PackRule,
    metrics: &mut dyn MetricsSource,
    warnings: &mut Vec<PackWarning>,
) -> Result<HBox, TeXError> {
    let scan = scan_h(&list, metrics)?;
    let totals = scan.totals;
    let suppress = matches!(rule, PackRule::Spread(_));
    let mut boxed = HBox::new();
    boxed.height = scan.height;
    boxed.depth = scan.depth;
    match rule {
        PackRule::Natural => {
            boxed.width = scan.width;
        }
        PackRule::Spread(want) => {
            let target = sum_sp([scan.width, want])?;
            let (setting, ratio) = set_glue(scan.width, target, suppress, &totals, warnings)?;
            boxed.glue_setting = setting;
            boxed.glue_set = ratio;
            boxed.width = target;
        }
        PackRule::To(goal) => {
            let (setting, ratio) = set_glue(scan.width, goal, false, &totals, warnings)?;
            boxed.glue_setting = setting;
            boxed.glue_set = ratio;
            boxed.width = goal;
        }
    }
    boxed.list = list;
    Ok(boxed)
}

/// Packs the list into a vertical box (tex.web's `vpack`): heights roll
/// with each member's depth, the box's depth is the last member's
/// depth, the width is the widest shifted member; the same packing
/// rules as `hpack`.
pub fn vpack(
    list: Vec<Node>,
    rule: PackRule,
    warnings: &mut Vec<PackWarning>,
) -> Result<VBox, TeXError> {
    let mut width = Scaled(0);
    let members = measure_v(&list)?;
    let mut height: Scaled = Scaled(0);
    let mut depth: Scaled = Scaled(0);
    let mut totals = GlueTotals::default();
    for member in &members {
        match member {
            VMember::Item { width: w, height: h, depth: d } => {
                height = sum_sp([height, depth, *h])?;
                depth = *d;
                if width.0 < w.0 {
                    width = *w;
                }
            }
            VMember::Glue(glue) => {
                height = sum_sp([height, depth, glue.width])?;
                depth = Scaled(0);
                totals.add(glue)?;
            }
            VMember::Kern(kern) => {
                height = sum_sp([height, depth, *kern])?;
            }
            VMember::Skip => {}
        }
    }
    let mut boxed = VBox::new();
    boxed.depth = depth;
    boxed.width = width;
    // Natural height excludes the last member's depth (tex.web: the
    // vbox's depth *is* that depth, so adding it would double-count).
    let natural = height;
    match rule {
        PackRule::Natural => {
            boxed.height = natural;
        }
        PackRule::Spread(want) => {
            let target = sum_sp([natural, want])?;
            let (setting, ratio) = set_glue(natural, target, true, &totals, warnings)?;
            boxed.glue_setting = setting;
            boxed.glue_set = ratio;
            boxed.height = target;
        }
        PackRule::To(goal) => {
            let (setting, ratio) = set_glue(natural, goal, false, &totals, warnings)?;
            boxed.glue_setting = setting;
            boxed.glue_set = ratio;
            boxed.height = goal;
        }
    }
    boxed.list = list;
    Ok(boxed)
}
