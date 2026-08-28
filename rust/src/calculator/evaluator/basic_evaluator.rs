use crate::calculator::{error::CalcError, evaluator::Evaluator, rational::CalcValue};

use flutter_rust_bridge::frb;

/// A basic evaluator that does not support variable resolution.
/// Designed for the standard calculator mode.
#[frb(ignore)]
pub struct BasicEvaluator {
    pub is_degree: bool,
    pub ans_value: f64,
}

impl BasicEvaluator {
    pub fn new(is_degree: bool, ans_value: f64) -> Self {
        Self {
            is_degree,
            ans_value,
        }
    }
}

impl Evaluator for BasicEvaluator {
    fn resolve_variable(&self, name: &str) -> Result<CalcValue, CalcError> {
        Err(CalcError::UnknownVariable(name.to_string()))
    }

    fn is_degree(&self) -> bool {
        self.is_degree
    }
    fn ans_value(&self) -> f64 {
        self.ans_value
    }
}
