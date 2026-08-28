use std::fmt;

#[derive(Debug, Clone, PartialEq)]
pub enum CommonError {
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

impl fmt::Display for CommonError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            CommonError::InvalidExpression(msg) => write!(f, "Invalid Expression: {}", msg),
            CommonError::InvalidToken(msg) => write!(f, "Invalid Token: {}", msg),
            CommonError::MissingOperand(msg) => write!(f, "Missing Operand: {}", msg),
            CommonError::MissingClosingParenthesis => write!(f, "Missing Closing Parenthesis"),
            CommonError::InvalidFunction(msg) => write!(f, "Invalid Function: {}", msg),
            CommonError::UnknownVariable(msg) => write!(f, "Unknown Variable: {}", msg),
            CommonError::InvalidArgumentCount(msg) => write!(f, "Invalid Argument Count: {}", msg),
            CommonError::DivisionByZero => write!(f, "Division by Zero"),
            CommonError::Overflow => write!(f, "Overflow"),
            CommonError::DomainError(msg) => write!(f, "Domain Error: {}", msg),
            CommonError::IoError(msg) => write!(f, "IO Error: {}", msg),
        }
    }
}

impl std::error::Error for CommonError {}
