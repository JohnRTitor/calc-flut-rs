use std::fmt;

/// Represents errors that can occur during mathematical evaluation or parsing.
#[derive(Debug, Clone)]
pub enum CalcError {
    InvalidExpression(String),
    InvalidToken(String),
    MissingOperand(String),
    MissingClosingParenthesis,
    InvalidFunction(String),
    UnknownVariable(String),
    InvalidArgumentCount(String),
    DivisionByZero,
    Overflow,
    DomainError(String),
    IoError(String),
}

impl fmt::Display for CalcError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            CalcError::InvalidExpression(msg) => write!(f, "Invalid Expression: {}", msg),
            CalcError::InvalidToken(msg) => write!(f, "Invalid Token: {}", msg),
            CalcError::MissingOperand(msg) => write!(f, "Missing Operand: {}", msg),
            CalcError::MissingClosingParenthesis => write!(f, "Missing Closing Parenthesis"),
            CalcError::InvalidFunction(msg) => write!(f, "Invalid Function: {}", msg),
            CalcError::UnknownVariable(msg) => write!(f, "Unknown Variable: {}", msg),
            CalcError::InvalidArgumentCount(msg) => write!(f, "Invalid Argument Count: {}", msg),
            CalcError::DivisionByZero => write!(f, "Division By Zero"),
            CalcError::Overflow => write!(f, "Overflow"),
            CalcError::DomainError(msg) => write!(f, "Domain Error: {}", msg),
            CalcError::IoError(msg) => write!(f, "IO Error: {}", msg),
        }
    }
}

// Needed for flutter_rust_bridge Result returns
impl std::error::Error for CalcError {}

impl From<crate::shared::error::CommonError> for CalcError {
    fn from(err: crate::shared::error::CommonError) -> Self {
        match err {
            crate::shared::error::CommonError::InvalidExpression(msg) => {
                CalcError::InvalidExpression(msg)
            }
            crate::shared::error::CommonError::InvalidToken(msg) => CalcError::InvalidToken(msg),
            crate::shared::error::CommonError::MissingOperand(msg) => {
                CalcError::MissingOperand(msg)
            }
            crate::shared::error::CommonError::MissingClosingParenthesis => {
                CalcError::MissingClosingParenthesis
            }
            crate::shared::error::CommonError::InvalidFunction(msg) => {
                CalcError::InvalidFunction(msg)
            }
            crate::shared::error::CommonError::UnknownVariable(msg) => {
                CalcError::UnknownVariable(msg)
            }
            crate::shared::error::CommonError::InvalidArgumentCount(msg) => {
                CalcError::InvalidArgumentCount(msg)
            }
            crate::shared::error::CommonError::DivisionByZero => CalcError::DivisionByZero,
            crate::shared::error::CommonError::Overflow => CalcError::Overflow,
            crate::shared::error::CommonError::DomainError(msg) => CalcError::DomainError(msg),
            crate::shared::error::CommonError::IoError(msg) => CalcError::IoError(msg),
        }
    }
}
