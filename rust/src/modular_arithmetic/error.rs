use std::fmt;

/// Represents errors that can occur during modular arithmetic evaluation or parsing.
#[derive(Debug, Clone)]
pub enum ModError {
    InvalidModulus(String),
    InverseDoesNotExist(String),
    NotPrime(String),
    InconsistentCRT(String),
    DivisionByZero,
    InvalidExpression(String),
    InvalidToken(String),
    MissingOperand(String),
    MissingClosingParenthesis,
    InvalidFunction(String),
    UnknownVariable(String),
    InvalidArgumentCount(String),
    InvalidPolynomial(String),
    Overflow,
    NoSolution(String),
    TooLarge(String),
    NoPrimitiveRoot(String),
}

impl fmt::Display for ModError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            ModError::InvalidModulus(msg) => write!(f, "Invalid Modulus: {}", msg),
            ModError::InverseDoesNotExist(msg) => write!(f, "Inverse does not exist: {}", msg),
            ModError::NotPrime(msg) => write!(f, "Not Prime: {}", msg),
            ModError::InconsistentCRT(msg) => write!(f, "Inconsistent CRT system: {}", msg),
            ModError::DivisionByZero => write!(f, "Division By Zero"),
            ModError::InvalidExpression(msg) => write!(f, "Invalid Expression: {}", msg),
            ModError::InvalidToken(msg) => write!(f, "Invalid Token: {}", msg),
            ModError::MissingOperand(msg) => write!(f, "Missing Operand: {}", msg),
            ModError::MissingClosingParenthesis => write!(f, "Missing Closing Parenthesis"),
            ModError::InvalidFunction(msg) => write!(f, "Invalid Function: {}", msg),
            ModError::UnknownVariable(msg) => write!(f, "Unknown Variable: {}", msg),
            ModError::InvalidArgumentCount(msg) => write!(f, "Invalid Argument Count: {}", msg),
            ModError::InvalidPolynomial(msg) => write!(f, "Invalid Polynomial: {}", msg),
            ModError::Overflow => write!(f, "Overflow"),
            ModError::NoSolution(msg) => write!(f, "No Solution: {}", msg),
            ModError::TooLarge(msg) => write!(f, "Value too large: {}", msg),
            ModError::NoPrimitiveRoot(msg) => write!(f, "No primitive root: {}", msg),
        }
    }
}

impl std::error::Error for ModError {}

impl From<crate::shared::error::CommonError> for ModError {
    fn from(err: crate::shared::error::CommonError) -> Self {
        match err {
            crate::shared::error::CommonError::InvalidExpression(msg) => {
                ModError::InvalidExpression(msg)
            }
            crate::shared::error::CommonError::InvalidToken(msg) => ModError::InvalidToken(msg),
            crate::shared::error::CommonError::MissingOperand(msg) => ModError::MissingOperand(msg),
            crate::shared::error::CommonError::MissingClosingParenthesis => {
                ModError::MissingClosingParenthesis
            }
            crate::shared::error::CommonError::InvalidFunction(msg) => {
                ModError::InvalidFunction(msg)
            }
            crate::shared::error::CommonError::UnknownVariable(msg) => {
                ModError::UnknownVariable(msg)
            }
            crate::shared::error::CommonError::InvalidArgumentCount(msg) => {
                ModError::InvalidArgumentCount(msg)
            }
            crate::shared::error::CommonError::DivisionByZero => ModError::DivisionByZero,
            crate::shared::error::CommonError::Overflow => ModError::Overflow,
            crate::shared::error::CommonError::DomainError(msg) => {
                ModError::InvalidExpression(format!("Domain Error: {}", msg))
            }
            crate::shared::error::CommonError::IoError(msg) => {
                ModError::InvalidExpression(format!("IO Error: {}", msg))
            }
        }
    }
}
