use crate::calculator::error::CalcError;
use crate::calculator::evaluator::Evaluator;
use crate::calculator::rational::CalcValue;
use std::collections::HashMap;

use flutter_rust_bridge::frb;

/// An evaluator that supports variable resolution from a provided environment.
/// Designed for the function evaluator mode.
#[frb(ignore)]
pub struct FunctionEvaluator {
    pub vars: HashMap<String, f64>,
    pub is_degree: bool,
    pub ans_value: f64,
}

impl FunctionEvaluator {
    pub fn new(vars: HashMap<String, f64>, is_degree: bool, ans_value: f64) -> Self {
        Self {
            vars,
            is_degree,
            ans_value,
        }
    }
}

impl Evaluator for FunctionEvaluator {
    fn resolve_variable(&self, name: &str) -> Result<CalcValue, CalcError> {
        if let Some(&val) = self.vars.get(name) {
            // Support rational arithmetic internally if the variable is an exact integer
            if val.fract() == 0.0 && val >= (i128::MIN as f64) && val <= (i128::MAX as f64) {
                Ok(CalcValue::from_i128(val as i128, 1))
            } else {
                Ok(CalcValue::from_f64(val))
            }
        } else {
            Err(CalcError::UnknownVariable(name.to_string()))
        }
    }

    fn is_degree(&self) -> bool {
        self.is_degree
    }
    fn ans_value(&self) -> f64 {
        self.ans_value
    }
}
