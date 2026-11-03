// Copyright (c) 2026 Divith123. Licensed under the MIT License.

//! Dimensions — tex.web's fixed-point arithmetic (§101, §114).
//!
//! TeX measures everything in `scaled` units: 2¹⁶ units per printer's
//! point. The faithful range is not `i32` but TeX's own: the magnitude
//! of any dimension stays below 2³⁰ (tex.web's largest legal dimen is
//! 2³⁰−1 `sp`, about 16384 pt — the TeXbook quotes `16383.99999pt`), and
//! tex.web aborts with `dimension too large` when an operation leaves
//! that range. Every helper below reports that condition as
//! [`crate::tex::TeXError::DimensionTooLarge`] instead of wrapping.

use crate::tex::TeXError;

/// One `scaled`: 65536 units per printer's point (tex.web §101).
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq, PartialOrd, Ord)]
pub struct Scaled(pub i32);

/// The largest magnitude tex.web permits for a dimension.
pub const DIMEN_LIMIT: i32 = (1 << 30) - 1;

/// Converts a 64-bit fixed-point value into a [`Scaled`], taking the
/// tex.web branch when the magnitude leaves the legal dimen range.
pub fn from_64(value: i64) -> Result<Scaled, TeXError> {
    if value > DIMEN_LIMIT as i64 || value < -(DIMEN_LIMIT as i64) {
        return Err(TeXError::DimensionTooLarge);
    }
    Ok(Scaled(value as i32))
}

/// Scales a dimension by an integer factor, with tex.web's 64-bit
/// intermediate precision (§114).
pub fn mult_sp(sp: Scaled, factor: i32) -> Result<Scaled, TeXError> {
    from_64(sp.0 as i64 * factor as i64)
}

/// Divides a dimension by an integer factor, truncating toward zero
/// (TeX's `\divide` rule; tex.web has no rounding on scaled/integer).
pub fn div_sp(sp: Scaled, factor: i32) -> Result<Scaled, TeXError> {
    if factor == 0 {
        return Err(TeXError::DivisionByZero);
    }
    Ok(Scaled(sp.0 / factor))
}

/// Adds dimensions, accumulated at 64 bits, with the range check tex.web
/// applies after every arithmetic step.
pub fn sum_sp(values: impl IntoIterator<Item = Scaled>) -> Result<Scaled, TeXError> {
    let mut total: i64 = 0;
    for value in values {
        total += value.0 as i64;
        if total > DIMEN_LIMIT as i64 || total < -(DIMEN_LIMIT as i64) {
            return Err(TeXError::DimensionTooLarge);
        }
    }
    Ok(Scaled(total as i32))
}
