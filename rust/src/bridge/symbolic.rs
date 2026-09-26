//! Asynchronous bridge surface for symbolic (CAS) operations.
//!
//! Every function here intentionally omits `#[frb(sync)]`, unlike the rest of
//! the bridge. Symbolic simplification, expansion and factorisation have no
//! predictable upper bound on their runtime, and a synchronous FFI call would
//! block the Flutter UI thread — freezing the keypad and risking an Android
//! ANR. Omitting the attribute makes flutter_rust_bridge dispatch the work off
//! the calling thread and hand Dart a `Future`.
//!
//! Errors cross the boundary as a structured [`SymbolicErrorInfo`] rather than
//! a bare `String`, so the Dart side never has to string-scrub wrapper syntax
//! out of a message to display it.

use flutter_rust_bridge::frb;

use crate::symbolic::error::{SymbolicError, SymbolicErrorKind};
use crate::symbolic::evaluator::{self, SymbolicOperation};

/// A structured error, safe to display verbatim.
///
/// [kind] lets the UI distinguish "you typed something wrong" from "that is
/// genuinely too big to do", and drives whether the app's Learn More
/// limitation banner is shown alongside the message.
#[frb]
pub struct SymbolicErrorInfo {
    /// A short, stable category: `input`, `unsupported`, `computation` or
    /// `too_large`.
    pub kind: String,
    /// The message to show, already in plain English.
    pub message: String,
    /// An optional short follow-up hint, or `None` when the message already
    /// explains itself.
    pub suggestion: Option<String>,
}

impl From<&SymbolicError> for SymbolicErrorInfo {
    fn from(error: &SymbolicError) -> Self {
        SymbolicErrorInfo {
            kind: match error.kind() {
                SymbolicErrorKind::Input => "input",
                SymbolicErrorKind::Unsupported => "unsupported",
                SymbolicErrorKind::Computation => "computation",
                SymbolicErrorKind::TooLarge => "too_large",
            }
            .to_string(),
            message: error.to_string(),
            suggestion: error.suggestion(),
        }
    }
}

/// One alternative representation of the same expression, offered as a
/// tappable chip under the primary result.
#[frb]
pub struct AlternateForm {
    /// The form's name, e.g. `Expanded`.
    pub label: String,
    /// The expression written in that form.
    pub expression: String,
}

/// The result of a symbolic operation.
#[frb]
pub struct SymbolicResult {
    /// The requested form, as the primary value.
    pub value: String,
    /// The remaining forms of the same expression, computed in the same call so
    /// switching form costs no extra round trip.
    pub alternate_forms: Vec<AlternateForm>,
    /// A short qualifier, e.g. that factorisation found nothing to pull out.
    pub details: Option<String>,
    /// Step-by-step working, present only when `show_steps` was requested.
    pub steps: Option<String>,
}

/// The symbolic operations this build supports, for the reference dialog.
///
/// Returning them from Rust keeps the list a single source of truth rather than
/// a hand-maintained literal in the UI that can drift from the parser above.
#[frb(sync)]
pub fn symbolic_operations() -> Vec<String> {
    SymbolicOperation::ALL
        .iter()
        .map(|op| op.verb().to_string())
        .collect()
}

/// Applies a symbolic operation to `expression`.
///
/// `operation` is one of `simplify`, `expand`, `factor` or `differentiate`.
/// `variable` names the variable to act on for the operations that need one;
/// pass an empty string (or `None`) when it is not needed or not yet chosen.
/// `show_steps` mirrors the existing `modular_evaluate` parameter and is gated
/// by Educational Mode.
///
/// Runs off the UI thread; see the module docs.
#[frb]
pub async fn symbolic_transform(
    expression: String,
    operation: String,
    variable: Option<String>,
    show_steps: bool,
) -> Result<SymbolicResult, SymbolicErrorInfo> {
    let operation = SymbolicOperation::from_name(&operation)
        .map_err(|e| SymbolicErrorInfo::from(&e))?;

    evaluator::transform(&expression, operation, variable.as_deref(), show_steps)
        .map(|outcome| SymbolicResult {
            value: outcome.value,
            alternate_forms: outcome
                .alternate_forms
                .into_iter()
                .map(|form| AlternateForm {
                    label: form.label,
                    expression: form.expression,
                })
                .collect(),
            details: outcome.details,
            steps: outcome.steps,
        })
        .map_err(|e| SymbolicErrorInfo::from(&e))
}
