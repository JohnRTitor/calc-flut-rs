use crate::modular_arithmetic::{error::ModError, mod_arith, number_theory, parser::ModExpr};

pub struct ModResult {
    pub value: String,
    pub details: Option<String>,
    pub modulus_used: Option<i128>,
    pub steps: Option<String>,
}

impl ModResult {
    pub fn simple(value: String) -> Self {
        ModResult {
            value,
            details: None,
            modulus_used: None,
            steps: None,
        }
    }

    pub fn with_details(value: String, details: String) -> Self {
        ModResult {
            value,
            details: Some(details),
            modulus_used: None,
            steps: None,
        }
    }

    pub fn with_modulus(value: String, details: String, modulus: i128) -> Self {
        ModResult {
            value,
            details: Some(details),
            modulus_used: Some(modulus),
            steps: None,
        }
    }

    pub fn with_steps(mut self, steps: Option<String>) -> Self {
        self.steps = steps;
        self
    }
}

pub fn format_set<T: std::fmt::Display>(items: &[T]) -> String {
    format!(
        "{{{}}}",
        items
            .iter()
            .map(|n| n.to_string())
            .collect::<Vec<_>>()
            .join(", ")
    )
}

#[derive(Debug, Clone, Copy)]
pub enum StructureMode {
    Ring,
    Field,
    Crt,
}

#[allow(clippy::collapsible_if)]
pub fn evaluate_mod_expr(
    expr: &ModExpr,
    context_modulus: Option<i128>,
    mode: StructureMode,
    show_steps: bool,
) -> Result<ModResult, ModError> {
    if let StructureMode::Field = mode {
        if let Some(m) = context_modulus {
            if !mod_arith::is_prime(m) {
                return Err(ModError::NotPrime(format!(
                    "{} is not prime. Field mode requires a prime modulus.",
                    m
                )));
            }
        }
    }

    let result = eval(expr, context_modulus)?;

    // Check if the top-level expression is one of the special ones that return details
    match expr {
        ModExpr::Egcd(a, b) => {
            let val_a = eval(a, context_modulus)?;
            let val_b = eval(b, context_modulus)?;
            let (g, x, y) = number_theory::extended_gcd(val_a, val_b);
            let steps = if show_steps {
                Some(format!(
                    "Using Extended Euclidean Algorithm on {} and {}",
                    val_a, val_b
                ))
            } else {
                None
            };
            Ok(ModResult::with_details(
                g.to_string(),
                format!("Bézout: {}({}) + {}({}) = {}", val_a, x, val_b, y, g),
            )
            .with_steps(steps))
        }
        ModExpr::Crt(pairs) => {
            let mut eval_pairs = Vec::new();
            for (r_expr, m_expr) in pairs {
                let r = eval(r_expr, context_modulus)?;
                let m = eval(m_expr, context_modulus)?;
                eval_pairs.push((r, m));
            }
            let (sol, m) = number_theory::crt(&eval_pairs)?;
            Ok(ModResult::with_modulus(
                sol.to_string(),
                format!("Solution modulo {}", m),
                m,
            ))
        }
        ModExpr::Totient(a) => {
            let val_a = eval(a, context_modulus)?;
            let phi = crate::modular_arithmetic::number_theory_ext::euler_totient(val_a);
            let steps = if show_steps {
                let factors =
                    crate::modular_arithmetic::number_theory_ext::prime_factorization(val_a);
                let mut s = format!("Prime factorization of {}:\n", val_a);
                for (p, e) in &factors {
                    s.push_str(&format!("{}^{} ", p, e));
                }
                Some(s)
            } else {
                None
            };
            Ok(
                ModResult::with_details(phi.to_string(), format!("φ({}) = {}", val_a, phi))
                    .with_steps(steps),
            )
        }
        ModExpr::Order(a, m) => {
            let val_a = eval(a, context_modulus)?;
            let val_m = eval(m, context_modulus)?;
            let ord = crate::modular_arithmetic::number_theory_ext::element_order(val_a, val_m)?;
            Ok(ModResult::with_modulus(
                ord.to_string(),
                format!("ord({}) mod {}", val_a, val_m),
                val_m,
            ))
        }
        ModExpr::PrimitiveRoots(m) => {
            let val_m = eval(m, context_modulus)?;
            let roots = crate::modular_arithmetic::number_theory_ext::primitive_roots(val_m)?;
            Ok(ModResult::with_modulus(
                format_set(&roots),
                format!("{} generators for Z_{}*", roots.len(), val_m),
                val_m,
            ))
        }
        ModExpr::Units(m) => {
            let val_m = eval(m, context_modulus)?;
            let u = crate::modular_arithmetic::number_theory_ext::unit_group(val_m);
            Ok(ModResult::with_modulus(
                format_set(&u),
                format!("|Z_{}*| = {}", val_m, u.len()),
                val_m,
            ))
        }
        ModExpr::ZeroDivisors(m) => {
            let val_m = eval(m, context_modulus)?;
            let zd = crate::modular_arithmetic::ring_analysis::zero_divisors_limited(val_m, 10000);
            Ok(ModResult::with_modulus(
                format_set(&zd),
                format!("{} zero divisors in Z_{}", zd.len(), val_m),
                val_m,
            ))
        }
        ModExpr::Idempotents(m) => {
            let val_m = eval(m, context_modulus)?;
            let id = crate::modular_arithmetic::ring_analysis::idempotents_limited(val_m, 10000);
            Ok(ModResult::with_modulus(
                format_set(&id),
                format!("{} idempotents in Z_{}", id.len(), val_m),
                val_m,
            ))
        }
        ModExpr::Nilpotents(m) => {
            let val_m = eval(m, context_modulus)?;
            let ni = crate::modular_arithmetic::ring_analysis::nilpotents_limited(val_m, 10000);
            let ni_str = format!(
                "{{{}}}",
                ni.iter()
                    .map(|n| n.to_string())
                    .collect::<Vec<_>>()
                    .join(", ")
            );
            Ok(ModResult {
                value: ni_str,
                details: Some(format!("{} nilpotents in Z_{}", ni.len(), val_m)),
                modulus_used: Some(val_m),
                steps: None,
            })
        }
        ModExpr::AdditiveInverse(a, m) => {
            let val_a = eval(a, context_modulus)?;
            let val_m = eval(m, context_modulus)?;
            let inv = crate::modular_arithmetic::number_theory_ext::additive_inverse(val_a, val_m);
            Ok(ModResult::with_modulus(
                inv.to_string(),
                format!("Additive inverse of {} mod {}", val_a, val_m),
                val_m,
            ))
        }
        ModExpr::Legendre(a, p) => {
            let val_a = eval(a, context_modulus)?;
            let val_p = eval(p, context_modulus)?;
            let l = crate::modular_arithmetic::quadratic::legendre_symbol(val_a, val_p)?;
            Ok(ModResult::with_modulus(
                l.to_string(),
                format!("({} / {}) Legendre symbol", val_a, val_p),
                val_p,
            ))
        }
        ModExpr::Jacobi(a, n) => {
            let val_a = eval(a, context_modulus)?;
            let val_n = eval(n, context_modulus)?;
            let j = crate::modular_arithmetic::quadratic::jacobi_symbol(val_a, val_n)?;
            Ok(ModResult::with_modulus(
                j.to_string(),
                format!("({} / {}) Jacobi symbol", val_a, val_n),
                val_n,
            ))
        }
        ModExpr::SqrtMod(a, p) => {
            let val_a = eval(a, context_modulus)?;
            let val_p = eval(p, context_modulus)?;
            let roots = crate::modular_arithmetic::quadratic::sqrt_mod(val_a, val_p)?;
            Ok(ModResult::with_modulus(
                format_set(&roots),
                format!("Square roots of {} mod {}", val_a, val_p),
                val_p,
            ))
        }
        ModExpr::SolveCongruence(a, b, m) => {
            let val_a = eval(a, context_modulus)?;
            let val_b = eval(b, context_modulus)?;
            let val_m = eval(m, context_modulus)?;
            let sols = crate::modular_arithmetic::number_theory_ext::solve_linear_congruence(
                val_a, val_b, val_m,
            )?;
            Ok(ModResult::with_modulus(
                format_set(&sols),
                format!("Solutions for {}x ≡ {} (mod {})", val_a, val_b, val_m),
                val_m,
            ))
        }
        ModExpr::DiscreteLog(g, a, p) => {
            let val_g = eval(g, context_modulus)?;
            let val_a = eval(a, context_modulus)?;
            let val_p = eval(p, context_modulus)?;
            let log =
                crate::modular_arithmetic::number_theory_ext::discrete_log(val_g, val_a, val_p)?;
            Ok(ModResult::with_modulus(
                log.to_string(),
                format!(
                    "x = {}, such that {}^x ≡ {} (mod {})",
                    log, val_g, val_a, val_p
                ),
                val_p,
            ))
        }
        ModExpr::QuadraticResidues(m) => {
            let val_m = eval(m, context_modulus)?;
            let qr = crate::modular_arithmetic::quadratic::quadratic_residues(val_m);
            Ok(ModResult::with_modulus(
                format_set(&qr),
                format!("{} quadratic residues mod {}", qr.len(), val_m),
                val_m,
            ))
        }
        ModExpr::Analyze(m) => {
            let val_m = eval(m, context_modulus)?;
            let info = crate::modular_arithmetic::ring_analysis::ring_classify(val_m);
            Ok(ModResult::with_modulus(
                format!("Z_{} Analysis", val_m),
                format!(
                    "Classification: {}\nIntegral Domain: {}\nField: {}\n|Units|: {}\n|Zero Divisors|: {}",
                    info.classification,
                    info.is_integral_domain,
                    info.is_field,
                    info.units.len(),
                    info.zero_divisors.len()
                ),
                val_m,
            ))
        }
        ModExpr::CayleyAdd(m) | ModExpr::CayleyMul(m) => {
            let val_m = eval(m, context_modulus)?;
            let is_add = matches!(expr, ModExpr::CayleyAdd(_));
            let table = if is_add {
                crate::modular_arithmetic::cayley::addition_table(val_m)?
            } else {
                crate::modular_arithmetic::cayley::multiplication_table(val_m)?
            };

            let mut s = String::new();
            for row in table {
                s.push_str(
                    &row.iter()
                        .map(|n| format!("{:3}", n))
                        .collect::<Vec<_>>()
                        .join(" "),
                );
                s.push('\n');
            }
            Ok(ModResult::with_modulus(
                if is_add {
                    "Addition Table".to_string()
                } else {
                    "Multiplication Table".to_string()
                },
                s,
                val_m,
            ))
        }
        _ => {
            let m_used = match expr {
                ModExpr::Modulo(_, m) => Some(eval(m, context_modulus)?),
                ModExpr::PowMod(_, _, m) => Some(eval(m, context_modulus)?),
                ModExpr::Inv(_, m) => Some(eval(m, context_modulus)?),
                _ => context_modulus,
            };

            let final_val = if let Some(m) = m_used {
                mod_arith::mod_reduce(result, m)
            } else {
                result
            };

            let mut res = ModResult::simple(final_val.to_string());
            res.modulus_used = m_used;
            Ok(res)
        }
    }
}

fn eval_binary_op(
    a: &ModExpr,
    b: &ModExpr,
    context_modulus: Option<i128>,
    plain_op: fn(i128, i128) -> i128,
    mod_op: fn(i128, i128, i128) -> i128,
) -> Result<i128, ModError> {
    let va = eval(a, context_modulus)?;
    let vb = eval(b, context_modulus)?;
    Ok(match context_modulus {
        Some(m) => mod_op(va, vb, m),
        None => plain_op(va, vb),
    })
}

fn eval(expr: &ModExpr, context_modulus: Option<i128>) -> Result<i128, ModError> {
    match expr {
        ModExpr::Number(n) => Ok(*n),
        ModExpr::Add(a, b) => {
            eval_binary_op(a, b, context_modulus, |a, b| a + b, mod_arith::mod_add)
        }
        ModExpr::Subtract(a, b) => {
            eval_binary_op(a, b, context_modulus, |a, b| a - b, mod_arith::mod_sub)
        }
        ModExpr::Multiply(a, b) => {
            eval_binary_op(a, b, context_modulus, |a, b| a * b, mod_arith::mod_mul)
        }
        ModExpr::Divide(a, b) => {
            let val_a = eval(a, context_modulus)?;
            let val_b = eval(b, context_modulus)?;
            if val_b == 0 {
                return Err(ModError::DivisionByZero);
            }
            if let Some(m) = context_modulus {
                mod_arith::mod_div(val_a, val_b, m)
            } else {
                if val_a % val_b != 0 {
                    return Err(ModError::InvalidExpression(format!(
                        "{} is not divisible by {} without modulus",
                        val_a, val_b
                    )));
                }
                Ok(val_a / val_b)
            }
        }
        ModExpr::Power(a, b) => {
            let val_a = eval(a, context_modulus)?;
            let val_b = eval(b, context_modulus)?;
            if let Some(m) = context_modulus {
                mod_arith::mod_pow(val_a, val_b, m)
            } else {
                if val_b < 0 {
                    return Err(ModError::InvalidExpression(
                        "Negative exponent without modulus".to_string(),
                    ));
                }
                if val_b > u32::MAX as i128 {
                    return Err(ModError::Overflow);
                }
                val_a.checked_pow(val_b as u32).ok_or(ModError::Overflow)
            }
        }
        ModExpr::Modulo(a, b) => {
            let val_a = eval(a, context_modulus)?;
            let val_b = eval(b, context_modulus)?;
            if val_b <= 0 {
                return Err(ModError::InvalidModulus(
                    "Modulus must be positive".to_string(),
                ));
            }
            Ok(mod_arith::mod_reduce(val_a, val_b))
        }
        ModExpr::PowMod(a, b, m) => {
            let val_a = eval(a, context_modulus)?;
            let val_b = eval(b, context_modulus)?;
            let val_m = eval(m, context_modulus)?;
            mod_arith::mod_pow(val_a, val_b, val_m)
        }
        ModExpr::Inv(a, m) => {
            let val_a = eval(a, context_modulus)?;
            let val_m = eval(m, context_modulus)?;
            mod_arith::mod_inv(val_a, val_m)
        }
        ModExpr::Gcd(a, b) => {
            let val_a = eval(a, context_modulus)?;
            let val_b = eval(b, context_modulus)?;
            Ok(number_theory::gcd(val_a, val_b))
        }
        ModExpr::Egcd(a, b) => {
            let val_a = eval(a, context_modulus)?;
            let val_b = eval(b, context_modulus)?;
            let (g, _, _) = number_theory::extended_gcd(val_a, val_b);
            Ok(g)
        }
        ModExpr::Crt(pairs) => {
            let mut eval_pairs = Vec::new();
            for (r_expr, m_expr) in pairs {
                let r = eval(r_expr, context_modulus)?;
                let m = eval(m_expr, context_modulus)?;
                eval_pairs.push((r, m));
            }
            let (sol, _) = number_theory::crt(&eval_pairs)?;
            Ok(sol)
        }
        ModExpr::Negate(a) => {
            let val_a = eval(a, context_modulus)?;
            if let Some(m) = context_modulus {
                Ok(mod_arith::mod_neg(val_a, m))
            } else {
                Ok(-val_a)
            }
        }
        ModExpr::Totient(a)
        | ModExpr::Order(a, _)
        | ModExpr::PrimitiveRoots(a)
        | ModExpr::Units(a)
        | ModExpr::ZeroDivisors(a)
        | ModExpr::Idempotents(a)
        | ModExpr::Nilpotents(a)
        | ModExpr::AdditiveInverse(a, _)
        | ModExpr::Legendre(a, _)
        | ModExpr::Jacobi(a, _)
        | ModExpr::SqrtMod(a, _)
        | ModExpr::SolveCongruence(a, _, _)
        | ModExpr::DiscreteLog(a, _, _)
        | ModExpr::Analyze(a)
        | ModExpr::CayleyAdd(a)
        | ModExpr::CayleyMul(a)
        | ModExpr::QuadraticResidues(a) => {
            // eval should only be called on inner expression when computing final value recursively,
            // but these functions are evaluated at the top level evaluate_mod_expr
            eval(a, context_modulus)
        }
    }
}
