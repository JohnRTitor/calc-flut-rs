use std::fmt::Write as _;

use symplex::prelude::{Context, Ex, SimplifyOpts, Step};

use crate::shared::error::CommonError;
use crate::symbolic::error::{SymbolicError, SymbolicErrorKind};

/// Maximum input length accepted for a symbolic operation, in characters.
///
/// Symbolic simplification has no natural stopping point: a single extra pair
/// of brackets can multiply the work. Capping the *input* is the only cheap,
/// predictable guard available before the work starts, and it doubles as a
/// guard against pathological simplification. The cap is generous compared to
/// anything hand-typed on a phone keypad.
pub const MAX_EXPRESSION_CHARS: usize = 1000;

/// The symbolic transformations this build supports.
///
/// Modelled as an enum so the FFI boundary can stay a plain `String` (matching
/// the existing `modular_evaluate` convention) while the internals stay
/// exhaustively typed: an unrecognised name becomes a typed error rather than
/// silently doing nothing.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SymbolicOperation {
    /// Combine like terms and reduce to a canonical form.
    Simplify,
    /// Multiply out all products.
    Expand,
    /// Factorise over the integers.
    Factor,
}

/// Labels used for the alternate-forms chips on the result card.
///
/// Owned here so the Rust result and any future server-driven form list stay in
/// step with the operation names the user sees.
impl SymbolicOperation {
    /// The user-facing name of this operation.
    pub const fn label(self) -> &'static str {
        match self {
            SymbolicOperation::Simplify => "Simplified",
            SymbolicOperation::Expand => "Expanded",
            SymbolicOperation::Factor => "Factored",
        }
    }

    /// Every supported operation, in presentation order.
    pub const ALL: [SymbolicOperation; 3] = [
        SymbolicOperation::Simplify,
        SymbolicOperation::Expand,
        SymbolicOperation::Factor,
    ];

    /// Parses an operation name coming from the bridge layer.
    pub fn from_name(name: &str) -> Result<Self, SymbolicError> {
        match name.trim().to_ascii_lowercase().as_str() {
            "simplify" => Ok(SymbolicOperation::Simplify),
            "expand" => Ok(SymbolicOperation::Expand),
            "factor" | "factorise" | "factorize" => Ok(SymbolicOperation::Factor),
            _ => Err(SymbolicError::UnknownOperation(name.trim().to_string())),
        }
    }

    /// Runs this operation, producing the primary value.
    ///
    /// `input` is the expression as the user typed it, used only to render the
    /// steps fallback. `show_steps` additionally returns a rewrite trace for the
    /// Educational Mode steps block; leaving it off avoids the tracing work
    /// entirely.
    fn apply(
        self,
        expr: &Ex,
        target: Option<&Ex>,
        input: &str,
        show_steps: bool,
    ) -> Result<(Ex, Option<String>), SymbolicError> {
        match self {
            SymbolicOperation::Simplify => {
                if show_steps {
                    let opts = SimplifyOpts::default();
                    let (simplified, steps) = expr.simplify_traced(&opts);
                    let steps = format_steps(&steps, input, &simplified.to_string());
                    Ok((simplified, Some(steps)))
                } else {
                    Ok((expr.simplify(), None))
                }
            }
            SymbolicOperation::Expand => Ok((expr.expand(), None)),
            SymbolicOperation::Factor => {
                // Factoring is only defined relative to a variable. Refusing
                // clearly beats factoring a constant into a number.
                let target = target.ok_or(SymbolicError::NoVariable)?;
                Ok((expr.factor(target), None))
            }
        }
    }
}

/// One alternative representation of the same expression.
///
/// Named to stay distinct from the bridge's `AlternateForm` transport type:
/// flutter_rust_bridge keys generated objects by name, and two public types
/// sharing one name make it pick arbitrarily.
#[derive(Debug, Clone)]
pub struct FormVariant {
    /// The form's name, e.g. `Expanded`.
    pub label: String,
    /// The expression written in that form.
    pub expression: String,
}

/// The full outcome of a symbolic operation.
#[derive(Debug, Clone)]
pub struct TransformOutcome {
    /// The requested form, as the primary value.
    pub value: String,
    /// The other forms of the same expression, computed in the same call so
    /// the UI never has to make a second round trip to offer a form switch.
    pub alternate_forms: Vec<FormVariant>,
    /// A short qualifier, e.g. that factorisation found nothing to pull out.
    pub details: Option<String>,
    /// Step-by-step working, present only when `show_steps` was requested.
    pub steps: Option<String>,
}

/// Renders a rewrite trace as aligned, monospace-friendly working.
///
/// A trace can legitimately be empty: the parser canonicalises as it reads
/// (combining `2x + 3x` into `5*x` and cancelling `x/x` to `1` before any
/// rewrite rule gets a chance to fire), so "no rules fired" is normal rather
/// than a failure. Rather than render an empty box, the entered and resulting
/// forms are shown — that pairing *is* the working that happened.
fn format_steps(steps: &[Step], input: &str, result: &str) -> String {
    if steps.is_empty() {
        return format!("as entered:  {}\nresult:      {}", input, result);
    }

    let mut out = String::new();
    let _ = writeln!(out, "as entered:  {}", input);
    for step in steps {
        let _ = writeln!(out, "{}:", step.rule_name);
        let _ = writeln!(out, "  {}  ->  {}", step.before, step.after);
    }
    let _ = writeln!(out, "result:      {}", result);
    out.trim_end().to_string()
}

/// Applies `operation` to `expression`.
///
/// `variable` names the variable the operation acts on when it needs one
/// (factoring); it is ignored by operations that do not.
///
/// The variable is taken as a *name* rather than a pre-built handle on purpose.
/// Expression handles are bound to the [`Context`] that created them and the
/// backend panics when handles from two contexts meet, so taking a name makes
/// it structurally impossible for a caller to hand in a foreign handle — this
/// function owns the only context involved.
pub fn transform(
    expression: &str,
    operation: SymbolicOperation,
    variable: Option<&str>,
    show_steps: bool,
) -> Result<TransformOutcome, SymbolicError> {
    let trimmed = expression.trim();
    if trimmed.is_empty() {
        return Err(SymbolicError::EmptyExpression);
    }
    if trimmed.chars().count() > MAX_EXPRESSION_CHARS {
        return Err(SymbolicError::TooLarge(format!(
            "over {} characters",
            MAX_EXPRESSION_CHARS
        )));
    }

    let ctx = Context::new();
    let parsed = ctx
        .parse(trimmed)
        .map_err(|e| SymbolicError::from(CommonError::InvalidExpression(e.to_string())))?;

    // Resolved here, in the same context as `parsed`. Operations that ignore
    // the variable never look at it, so it is resolved lazily: asking for
    // `simplify` never fails over a malformed name it would not have used.
    let target = match variable.map(str::trim).filter(|name| !name.is_empty()) {
        Some(name) => Some(
            ctx.try_symbol(name)
                .map_err(|_| SymbolicError::InvalidExpression(format!("'{}' is not a usable variable name", name)))?,
        ),
        None => None,
    };
    let target = target.as_ref();

    let (value, steps) = operation.apply(&parsed, target, trimmed, show_steps)?;

    Ok(TransformOutcome {
        value: value.to_string(),
        alternate_forms: alternate_forms(&parsed, operation, target),
        details: details_for(operation, &parsed, target),
        steps,
    })
}

/// Computes the forms the user did *not* ask for, so the result card can offer
/// them as tappable chips without another bridge call.
///
/// A form that cannot be produced (for example factoring when no variable was
/// chosen) is simply absent rather than reported as an error: these are
/// conveniences, not the answer.
fn alternate_forms(
    parsed: &Ex,
    chosen: SymbolicOperation,
    target: Option<&Ex>,
) -> Vec<FormVariant> {
    let mut forms = Vec::new();

    for operation in SymbolicOperation::ALL {
        if operation == chosen {
            continue;
        }
        // Factoring is the only alternate form that needs the variable.
        let op_target = if operation == SymbolicOperation::Factor {
            target
        } else {
            None
        };
        if let Ok((expr, _)) = operation.apply(parsed, op_target, "", false) {
            forms.push(FormVariant {
                label: operation.label().to_string(),
                expression: expr.to_string(),
            });
        }
    }

    forms
}

/// Builds the short qualifier line under the primary value.
///
/// An expression that is already fully factorised is a genuinely different
/// outcome from one that factored, and saying so is more honest than showing
/// an unchanged expression as though something happened.
fn details_for(
    operation: SymbolicOperation,
    parsed: &Ex,
    target: Option<&Ex>,
) -> Option<String> {
    match operation {
        SymbolicOperation::Factor => {
            let target = target?;
            if parsed.factor(target).to_string() == parsed.expand().to_string() {
                Some("No further factors over the integers".to_string())
            } else {
                None
            }
        }
        SymbolicOperation::Simplify | SymbolicOperation::Expand => None,
    }
}

/// Classifies an error for the bridge layer.
pub const fn kind_of(error: &SymbolicError) -> SymbolicErrorKind {
    error.kind()
}
