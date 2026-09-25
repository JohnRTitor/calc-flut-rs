use std::fmt;

use symplex::prelude::SymplexError;

/// Errors raised by the symbolic (computer algebra) subsystem.
///
/// Every variant carries a message that is safe to show verbatim in the UI:
/// nothing here exposes backend crate names, Rust type names or internal
/// terminology. The bridge converts these into a structured
/// `SymbolicErrorInfo`, so Dart never has to string-scrub a `Result<_, String>`.
#[derive(Debug, Clone)]
pub enum SymbolicError {
    /// The user did not enter anything to work on.
    EmptyExpression,
    /// The input could not be parsed as a mathematical expression.
    InvalidExpression(String),
    /// The requested operation name is not one this build supports.
    UnknownOperation(String),
    /// The operation needs a free variable to act on, but there was none.
    NoVariable,
    /// The requested operation is valid but cannot be carried out as asked.
    NotSupported(String),
    /// A symbolic operation ran but could not produce an answer.
    ComputationFailed(String),
    /// The input exceeded a practical size/complexity budget.
    ///
    /// Surfaced with a "Learn More" explanation rather than a bare error, so the
    /// user learns why instead of seeing a dead end.
    TooLarge(String),
}

impl fmt::Display for SymbolicError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            SymbolicError::EmptyExpression => {
                write!(f, "Enter an expression to work on")
            }
            SymbolicError::InvalidExpression(msg) => write!(f, "Invalid expression: {}", msg),
            SymbolicError::UnknownOperation(op) => {
                write!(f, "Unsupported operation: {}", op)
            }
            SymbolicError::NoVariable => write!(f, "This expression has no variable to work with"),
            SymbolicError::NotSupported(msg) => write!(f, "Cannot do that: {}", msg),
            SymbolicError::ComputationFailed(msg) => write!(f, "Could not simplify: {}", msg),
            SymbolicError::TooLarge(msg) => write!(f, "Expression is too large: {}", msg),
        }
    }
}

impl std::error::Error for SymbolicError {}

impl From<CommonError> for SymbolicError {
    fn from(err: CommonError) -> Self {
        match err {
            CommonError::InvalidExpression(msg) => SymbolicError::InvalidExpression(msg),
            CommonError::InvalidToken(msg) | CommonError::MissingOperand(msg) => {
                SymbolicError::InvalidExpression(msg)
            }
            CommonError::MissingClosingParenthesis => SymbolicError::InvalidExpression(
                "missing a closing parenthesis".to_string(),
            ),
            CommonError::InvalidFunction(msg) => SymbolicError::NotSupported(msg),
            CommonError::UnknownVariable(msg) => SymbolicError::InvalidExpression(msg),
            CommonError::InvalidArgumentCount(msg) => SymbolicError::NotSupported(msg),
            CommonError::DivisionByZero => SymbolicError::NotSupported(
                "division by zero is undefined here".to_string(),
            ),
            CommonError::Overflow => SymbolicError::TooLarge(
                "the result does not fit in a finite value".to_string(),
            ),
            CommonError::DomainError(msg) => SymbolicError::NotSupported(msg),
            CommonError::IoError(msg) => SymbolicError::ComputationFailed(msg),
        }
    }
}

use crate::shared::error::CommonError;

/// Maps a backend computation failure onto a presentable variant.
///
/// The backend's own `Display` text is already plain English and is far more
/// useful than a generic "operation failed", so it is preserved as the
/// human-readable detail. Only the Rust type names it wraps
/// (`ComputationFailed { .. }`) are discarded.
impl From<SymplexError> for SymbolicError {
    fn from(err: SymplexError) -> Self {
        match err {
            SymplexError::FreeSymbol { name } => SymbolicError::NotSupported(format!(
                "the expression still contains the free symbol '{}'",
                name
            )),
            SymplexError::Unevaluable { reason } => SymbolicError::NotSupported(reason),
            SymplexError::Divergent { operation, reason } => {
                SymbolicError::ComputationFailed(format!("{} diverges: {}", operation, reason))
            }
            SymplexError::PrecisionExhausted {
                requested,
                achieved,
            } => SymbolicError::ComputationFailed(format!(
                "could not reach the requested precision of {} digits (reached {})",
                requested, achieved
            )),
            SymplexError::ContradictoryAssumptions { symbol, a, b } => {
                SymbolicError::NotSupported(format!(
                    "'{}' cannot be both {} and {}",
                    symbol, a, b
                ))
            }
            SymplexError::NotImplemented(what) => {
                SymbolicError::NotSupported(what)
            }
            other => SymbolicError::ComputationFailed(other.to_string()),
        }
    }
}

/// A machine-readable category for a [`SymbolicError`].
///
/// The Flutter layer switches on this to choose between a plain error message
/// and the "Learn More" limitation banner, so it must stay a small closed set.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SymbolicErrorKind {
    /// The user needs to fix their input.
    Input,
    /// The operation cannot be performed on this input.
    Unsupported,
    /// The backend could not produce an answer.
    Computation,
    /// A practical size/complexity limit was hit.
    TooLarge,
}

impl SymbolicError {
    /// Classifies this error for the UI layer.
    pub const fn kind(&self) -> SymbolicErrorKind {
        match self {
            SymbolicError::EmptyExpression | SymbolicError::InvalidExpression(_) => {
                SymbolicErrorKind::Input
            }
            SymbolicError::UnknownOperation(_)
            | SymbolicError::NoVariable
            | SymbolicError::NotSupported(_) => SymbolicErrorKind::Unsupported,
            SymbolicError::ComputationFailed(_) => SymbolicErrorKind::Computation,
            SymbolicError::TooLarge(_) => SymbolicErrorKind::TooLarge,
        }
    }

    /// A short, actionable follow-up shown under the error message.
    ///
    /// Returns `None` when the message is already self-explanatory, so the UI
    /// never renders a redundant hint.
    pub fn suggestion(&self) -> Option<String> {
        match self {
            SymbolicError::EmptyExpression => Some("Try something like (x + 1)*(x - 1)".into()),
            SymbolicError::InvalidExpression(_) => {
                Some("Check for a missing operator or unbalanced brackets".into())
            }
            SymbolicError::UnknownOperation(_) => None,
            SymbolicError::NoVariable => {
                Some("Include a letter, for example x^2 + 3*x".into())
            }
            SymbolicError::NotSupported(_) => None,
            SymbolicError::ComputationFailed(_) => {
                Some("Try a smaller expression, or a different form of it".into())
            }
            SymbolicError::TooLarge(_) => {
                Some("Break it into smaller steps and apply them one at a time".into())
            }
        }
    }
}
