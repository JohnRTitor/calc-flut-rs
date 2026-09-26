//! Symbolic (computer algebra) evaluation.
//!
//! This is a sibling of `calculator` (real-number fast path) and
//! `modular_arithmetic` (ring/field analysis), not an extension of either. The
//! numeric evaluator is deliberately left untouched: it stays synchronous and
//! keypress-latency sensitive, while everything here runs off the UI thread
//! through the async bridge in `crate::bridge::symbolic`.
//!
//! Backed by the `symplex` crate, which keeps exact `Ratio<BigInt>` arithmetic
//! throughout — no silent rounding, no float fallback.

pub mod error;
pub mod evaluator;
pub mod matrix;
pub mod ntheory;
pub mod plot;
pub mod solve;

pub use error::{SymbolicError, SymbolicErrorKind};
pub use matrix::{
    EigenEntry, MAX_CELLS, MatrixAnalysis, MatrixSpec, analyse as analyse_matrix,
};
pub use ntheory::{
    MAX_DIGITS as MAX_NUMBER_DIGITS, NumberAnalysis, PrimeFactor, analyse as analyse_number, coprime, gcd,
    lcm,
};
pub use plot::{DEFAULT_SAMPLES, PlotCurve, PlotSample, plot};
pub use solve::{SolutionCategory, SolveOutcome, solve};
pub use evaluator::{
    FORM_OPERATIONS, INDEFINITE_CONSTANT, LimitRange, MAX_EXPRESSION_CHARS, SymbolicOperation,
    TransformOutcome,
    transform,
};
