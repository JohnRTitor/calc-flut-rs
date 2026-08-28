pub mod basic_evaluator;
pub mod function_evaluator;

use {
    crate::calculator::{error::CalcError, parser::Expr, rational::CalcValue},
    std::collections::HashSet,
};

use num_traits::{One, Zero};
pub use {basic_evaluator::BasicEvaluator, function_evaluator::FunctionEvaluator};

/// Defines the capabilities of an evaluator, specifically how it resolves variables.
pub trait Evaluator {
    /// Resolves a variable name to its value.
    fn resolve_variable(&self, name: &str) -> Result<CalcValue, CalcError>;

    /// Whether trigonometric functions use degrees. Default: false (radians).
    fn is_degree(&self) -> bool {
        false
    }

    /// The previous answer value. Default: 0.0.
    fn ans_value(&self) -> f64 {
        0.0
    }
}

/// Evaluates an Abstract Syntax Tree (AST) expression and returns its computed value.
///
/// Handles rational arithmetic when possible for precision, and falls back to
/// floating-point representation when necessary (e.g., for trigonometric functions).
///
/// # Arguments
/// * `expr` - The mathematical expression (AST node) to evaluate.
/// * `evaluator` - The evaluation context (Basic or Function mode).
/// * `is_degree` - If true, trigonometric functions will interpret their inputs/outputs as degrees instead of radians.
/// * `ans_value` - The result of the previous calculation, used when the `Ans` token is encountered.
pub fn evaluate_expr(expr: &Expr, evaluator: &dyn Evaluator) -> Result<CalcValue, CalcError> {
    let is_degree = evaluator.is_degree();
    let ans_value = evaluator.ans_value();
    match expr {
        Expr::Number(n) => {
            if n.fract() == 0.0 && *n >= (i128::MIN as f64) && *n <= (i128::MAX as f64) {
                Ok(CalcValue::from_i128(*n as i128, 1))
            } else {
                Ok(CalcValue::from_f64(*n))
            }
        }
        Expr::Pi => Ok(CalcValue::pi_from_i128(1, 1)),
        Expr::E => Ok(CalcValue::from_f64(std::f64::consts::E)),
        Expr::Ans => {
            if ans_value.fract() == 0.0
                && ans_value >= (i128::MIN as f64)
                && ans_value <= (i128::MAX as f64)
            {
                Ok(CalcValue::from_i128(ans_value as i128, 1))
            } else {
                Ok(CalcValue::from_f64(ans_value))
            }
        }
        Expr::Variable(name) => evaluator.resolve_variable(name),
        Expr::Add(l, r) => Ok(evaluate_expr(l, evaluator)?.add(evaluate_expr(r, evaluator)?)),
        Expr::Subtract(l, r) => Ok(evaluate_expr(l, evaluator)?.sub(evaluate_expr(r, evaluator)?)),
        Expr::Multiply(l, r) => Ok(evaluate_expr(l, evaluator)?.mul(evaluate_expr(r, evaluator)?)),
        Expr::Divide(l, r) => evaluate_expr(l, evaluator)?
            .div(evaluate_expr(r, evaluator)?)
            .map_err(|_| CalcError::DivisionByZero),
        Expr::Modulo(l, r) => {
            // Optimization for modular exponentiation to prevent overflow
            if let Expr::Power(base_expr, exp_expr) = &**l {
                let base = evaluate_expr(base_expr, evaluator)?;
                let exp = evaluate_expr(exp_expr, evaluator)?;
                let modulus = evaluate_expr(r, evaluator)?;

                if let (CalcValue::Rational(b), CalcValue::Rational(e), CalcValue::Rational(m)) =
                    (&base, &exp, &modulus)
                    && b.is_integer()
                    && e.is_integer()
                    && m.is_integer()
                    && m.numer() > &num_bigint::BigInt::zero()
                {
                    use num_traits::ToPrimitive;
                    if let (Some(b_i128), Some(e_i128), Some(m_i128)) = (
                        b.numer().to_i128(),
                        e.numer().to_i128(),
                        m.numer().to_i128(),
                    ) {
                        // Use modular arithmetic engine
                        if let Ok(res) =
                            crate::modular_arithmetic::mod_arith::mod_pow(b_i128, e_i128, m_i128)
                        {
                            return Ok(CalcValue::from_i128(res, 1));
                        }
                    }
                }

                // Fallback to regular evaluation if not exact integers or modulus is negative/zero
                return base
                    .pow(exp)
                    .modulo(modulus)
                    .map_err(|_| CalcError::DivisionByZero);
            }

            evaluate_expr(l, evaluator)?
                .modulo(evaluate_expr(r, evaluator)?)
                .map_err(|_| CalcError::DivisionByZero)
        }
        Expr::Power(l, r) => {
            let left = evaluate_expr(l, evaluator)?;
            let right = evaluate_expr(r, evaluator)?;
            Ok(left.pow(right))
        }
        Expr::Negate(e) => Ok(evaluate_expr(e, evaluator)?.negate()),
        Expr::Factorial(e) => {
            let val = evaluate_expr(e, evaluator)?;
            if let CalcValue::Rational(r) = val
                && r.is_integer()
                && r.numer() >= &num_bigint::BigInt::zero()
            {
                let mut result = num_bigint::BigInt::one();
                let mut i = num_bigint::BigInt::one();
                let n = r.numer();
                // Arbitrary limit to prevent DOS from user putting 99999999999!
                use num_traits::ToPrimitive;
                if n.to_u32().unwrap_or(u32::MAX) > 10000 {
                    return Err(CalcError::Overflow);
                }
                while &i <= n {
                    result *= &i;
                    i += num_bigint::BigInt::one();
                }
                return Ok(CalcValue::Rational(
                    num_rational::BigRational::from_integer(result),
                ));
            }
            Err(CalcError::DomainError(
                "Factorial requires positive integer".to_string(),
            ))
        }
        Expr::Percentage(e) => {
            let val = evaluate_expr(e, evaluator)?;
            val.div(CalcValue::from_i128(100, 1))
                .map_err(|_| CalcError::DivisionByZero)
        }
        Expr::Sin(e) => {
            let val = evaluate_expr(e, evaluator)?.to_float();
            let mut res = if is_degree {
                val.to_radians().sin()
            } else {
                val.sin()
            };
            if is_degree && val % 180.0 == 0.0 {
                res = 0.0;
            }
            Ok(CalcValue::from_f64(res))
        }
        Expr::Cos(e) => {
            let val = evaluate_expr(e, evaluator)?.to_float();
            let mut res = if is_degree {
                val.to_radians().cos()
            } else {
                val.cos()
            };
            if is_degree && (val - 90.0) % 180.0 == 0.0 {
                res = 0.0;
            }
            Ok(CalcValue::from_f64(res))
        }
        Expr::Tan(e) => {
            let val = evaluate_expr(e, evaluator)?.to_float();
            if is_degree && (val - 90.0) % 180.0 == 0.0 {
                return Err(CalcError::DomainError("Tangent undefined".to_string()));
            }
            let mut res = if is_degree {
                val.to_radians().tan()
            } else {
                val.tan()
            };
            if is_degree && val % 180.0 == 0.0 {
                res = 0.0;
            }
            Ok(CalcValue::from_f64(res))
        }
        Expr::Asin(e) => {
            let val = evaluate_expr(e, evaluator)?.to_float();
            if !(-1.0..=1.0).contains(&val) {
                return Err(CalcError::DomainError(
                    "Asin is only defined for domain [-1, 1]".to_string(),
                ));
            }
            let res = val.asin();
            Ok(CalcValue::from_f64(if is_degree {
                res.to_degrees()
            } else {
                res
            }))
        }
        Expr::Acos(e) => {
            let val = evaluate_expr(e, evaluator)?.to_float();
            if !(-1.0..=1.0).contains(&val) {
                return Err(CalcError::DomainError(
                    "Acos is only defined for domain [-1, 1]".to_string(),
                ));
            }
            let res = val.acos();
            Ok(CalcValue::from_f64(if is_degree {
                res.to_degrees()
            } else {
                res
            }))
        }
        Expr::Atan(e) => {
            let val = evaluate_expr(e, evaluator)?.to_float();
            let res = val.atan();
            Ok(CalcValue::from_f64(if is_degree {
                res.to_degrees()
            } else {
                res
            }))
        }
        Expr::Sinh(e) => Ok(CalcValue::from_f64(
            evaluate_expr(e, evaluator)?.to_float().sinh(),
        )),
        Expr::Cosh(e) => Ok(CalcValue::from_f64(
            evaluate_expr(e, evaluator)?.to_float().cosh(),
        )),
        Expr::Tanh(e) => Ok(CalcValue::from_f64(
            evaluate_expr(e, evaluator)?.to_float().tanh(),
        )),
        Expr::Asinh(e) => Ok(CalcValue::from_f64(
            evaluate_expr(e, evaluator)?.to_float().asinh(),
        )),
        Expr::Acosh(e) => {
            let val = evaluate_expr(e, evaluator)?.to_float();
            if val < 1.0 {
                return Err(CalcError::DomainError(
                    "Acosh is only defined for numbers >= 1".to_string(),
                ));
            }
            Ok(CalcValue::from_f64(val.acosh()))
        }
        Expr::Atanh(e) => {
            let val = evaluate_expr(e, evaluator)?.to_float();
            if val <= -1.0 || val >= 1.0 {
                return Err(CalcError::DomainError(
                    "Atanh is only defined for domain (-1, 1)".to_string(),
                ));
            }
            Ok(CalcValue::from_f64(val.atanh()))
        }
        Expr::Log10(e) => {
            let val = evaluate_expr(e, evaluator)?.to_float();
            if val <= 0.0 {
                return Err(CalcError::DomainError(
                    "Log is only defined for positive numbers".to_string(),
                ));
            }
            Ok(CalcValue::from_f64(val.log10()))
        }
        Expr::Log { base, value } => {
            let b = evaluate_expr(base, evaluator)?.to_float();
            let v = evaluate_expr(value, evaluator)?.to_float();
            if b <= 0.0 || b == 1.0 {
                return Err(CalcError::DomainError("Invalid logarithm base".to_string()));
            }
            if v <= 0.0 {
                return Err(CalcError::DomainError(
                    "Logarithm value must be positive".to_string(),
                ));
            }
            Ok(CalcValue::from_f64(v.ln() / b.ln()))
        }
        Expr::Ln(e) => {
            let val = evaluate_expr(e, evaluator)?.to_float();
            if val <= 0.0 {
                return Err(CalcError::DomainError(
                    "Ln is only defined for positive numbers".to_string(),
                ));
            }
            Ok(CalcValue::from_f64(val.ln()))
        }
        Expr::Sqrt(e) => {
            let val = evaluate_expr(e, evaluator)?.to_float();
            if val < 0.0 {
                return Err(CalcError::DomainError(
                    "Square root is not defined for negative numbers".to_string(),
                ));
            }
            Ok(CalcValue::from_f64(val.sqrt()))
        }
    }
}

/// Recursively traverses the AST to extract all variable names.
pub fn extract_variables(expr: &Expr) -> HashSet<String> {
    let mut vars = HashSet::new();
    match expr {
        Expr::Variable(name) => {
            vars.insert(name.clone());
        }
        Expr::Add(l, r)
        | Expr::Subtract(l, r)
        | Expr::Multiply(l, r)
        | Expr::Divide(l, r)
        | Expr::Modulo(l, r)
        | Expr::Power(l, r)
        | Expr::Log { base: l, value: r } => {
            vars.extend(extract_variables(l));
            vars.extend(extract_variables(r));
        }
        Expr::Negate(e)
        | Expr::Factorial(e)
        | Expr::Percentage(e)
        | Expr::Sin(e)
        | Expr::Cos(e)
        | Expr::Tan(e)
        | Expr::Asin(e)
        | Expr::Acos(e)
        | Expr::Atan(e)
        | Expr::Sinh(e)
        | Expr::Cosh(e)
        | Expr::Tanh(e)
        | Expr::Asinh(e)
        | Expr::Acosh(e)
        | Expr::Atanh(e)
        | Expr::Log10(e)
        | Expr::Ln(e)
        | Expr::Sqrt(e) => {
            vars.extend(extract_variables(e));
        }
        Expr::Number(_) | Expr::Pi | Expr::E | Expr::Ans => {}
    }
    vars
}
