use {
    bigdecimal::{BigDecimal, ToPrimitive},
    num_bigint::BigInt,
    num_rational::BigRational,
    num_traits::{One, Zero},
};

/// Represents the evaluated value of an expression.
/// Can be a precise Rational, a multiple of Pi, or a fallback decimal value.
#[derive(Clone, Debug, PartialEq)]
pub enum CalcValue {
    Rational(BigRational),
    PiRational(BigRational),
    Float(BigDecimal),
}

impl CalcValue {
    /// Converts this `CalcValue` into a standard `f64` float.
    pub fn to_float(&self) -> f64 {
        match self {
            CalcValue::Rational(r) => r.to_f64().unwrap_or(f64::NAN),
            CalcValue::PiRational(r) => r.to_f64().unwrap_or(f64::NAN) * std::f64::consts::PI,
            CalcValue::Float(f) => f.to_f64().unwrap_or(f64::NAN),
        }
    }

    pub fn from_f64(f: f64) -> Self {
        CalcValue::Float(BigDecimal::try_from(f).unwrap_or_default())
    }

    pub fn from_i128(n: i128, d: i128) -> Self {
        CalcValue::Rational(BigRational::new(BigInt::from(n), BigInt::from(d)))
    }

    pub fn pi_from_i128(n: i128, d: i128) -> Self {
        CalcValue::PiRational(BigRational::new(BigInt::from(n), BigInt::from(d)))
    }

    pub fn to_big_decimal(&self) -> BigDecimal {
        match self {
            CalcValue::Rational(_) => {
                let f = self.to_float();
                BigDecimal::try_from(f).unwrap_or_default()
            }
            CalcValue::PiRational(_) => {
                let f = self.to_float();
                BigDecimal::try_from(f).unwrap_or_default()
            }
            CalcValue::Float(f) => f.clone(),
        }
    }

    /// Converts this `CalcValue` into an exact fraction string, if possible.
    pub fn to_exact_fraction_string(&self) -> Option<String> {
        match self {
            CalcValue::Rational(r) => {
                if !r.is_integer() {
                    Some(format!("{}/{}", r.numer(), r.denom()))
                } else {
                    None
                }
            }
            CalcValue::PiRational(r) => {
                if r.is_zero() {
                    Some("0".to_string())
                } else {
                    let num_str = if r.numer() == &BigInt::one() {
                        "π".to_string()
                    } else if r.numer() == &-BigInt::one() {
                        "-π".to_string()
                    } else {
                        format!("{}π", r.numer())
                    };
                    if r.denom() == &BigInt::one() {
                        Some(num_str)
                    } else {
                        Some(format!("{}/{}", num_str, r.denom()))
                    }
                }
            }
            _ => None,
        }
    }

    /// Adds two `CalcValue`s, preserving rationality if possible.
    #[allow(clippy::should_implement_trait)]
    pub fn add(self, other: CalcValue) -> CalcValue {
        match (self, other) {
            (CalcValue::Rational(r1), CalcValue::Rational(r2)) => CalcValue::Rational(r1 + r2),
            (CalcValue::PiRational(r1), CalcValue::PiRational(r2)) => {
                CalcValue::PiRational(r1 + r2)
            }
            (a, b) => CalcValue::Float(a.to_big_decimal() + b.to_big_decimal()),
        }
    }

    /// Subtracts `other` from `self`, preserving rationality if possible.
    #[allow(clippy::should_implement_trait)]
    pub fn sub(self, other: CalcValue) -> CalcValue {
        match (self, other) {
            (CalcValue::Rational(r1), CalcValue::Rational(r2)) => CalcValue::Rational(r1 - r2),
            (CalcValue::PiRational(r1), CalcValue::PiRational(r2)) => {
                CalcValue::PiRational(r1 - r2)
            }
            (a, b) => CalcValue::Float(a.to_big_decimal() - b.to_big_decimal()),
        }
    }

    /// Multiplies two `CalcValue`s, preserving rationality if possible.
    #[allow(clippy::should_implement_trait)]
    pub fn mul(self, other: CalcValue) -> CalcValue {
        match (self, other) {
            (CalcValue::Rational(r1), CalcValue::Rational(r2)) => CalcValue::Rational(r1 * r2),
            (CalcValue::Rational(r1), CalcValue::PiRational(r2))
            | (CalcValue::PiRational(r2), CalcValue::Rational(r1)) => {
                CalcValue::PiRational(r1 * r2)
            }
            (a, b) => CalcValue::Float(a.to_big_decimal() * b.to_big_decimal()),
        }
    }

    /// Divides `self` by `other`, preserving rationality if possible.
    /// Returns an error if dividing by zero.
    #[allow(clippy::should_implement_trait)]
    #[allow(clippy::result_unit_err)]
    pub fn div(self, other: CalcValue) -> Result<CalcValue, ()> {
        let other_f = other.to_float();
        if other_f == 0.0 {
            return Err(());
        }
        Ok(match (self, other) {
            (CalcValue::Rational(r1), CalcValue::Rational(r2)) => CalcValue::Rational(r1 / r2),
            (CalcValue::PiRational(r1), CalcValue::Rational(r2)) => CalcValue::PiRational(r1 / r2),
            (CalcValue::PiRational(r1), CalcValue::PiRational(r2)) => CalcValue::Rational(r1 / r2),
            (a, b) => {
                let res = a.to_float() / b.to_float();
                CalcValue::Float(BigDecimal::try_from(res).unwrap_or_default())
            }
        })
    }

    /// Computes `self % other`. Attempts exact integer modulo if possible.
    #[allow(clippy::result_unit_err)]
    pub fn modulo(self, other: CalcValue) -> Result<CalcValue, ()> {
        if other.to_float() == 0.0 {
            return Err(());
        }

        match (self, other) {
            (CalcValue::Rational(r1), CalcValue::Rational(r2))
                if r1.is_integer() && r2.is_integer() =>
            {
                let mut res = r1.numer() % r2.numer();
                if res < BigInt::zero() {
                    if r2.numer() > &BigInt::zero() {
                        res += r2.numer();
                    } else {
                        res -= r2.numer();
                    }
                }
                Ok(CalcValue::Rational(BigRational::from_integer(res)))
            }
            (a, b) => {
                let res = a.to_float() % b.to_float();
                Ok(CalcValue::Float(
                    BigDecimal::try_from(res).unwrap_or_default(),
                ))
            }
        }
    }

    /// Raises `self` to the power of `other`, attempting to preserve rationality for integer exponents.
    pub fn pow(self, other: CalcValue) -> CalcValue {
        match (self.clone(), other.clone()) {
            (CalcValue::Rational(r1), CalcValue::Rational(r2)) if r2.is_integer() => {
                // Integer exponent
                if let Some(exp) = r2.numer().to_i32() {
                    if exp >= 0 {
                        CalcValue::Rational(r1.pow(exp))
                    } else {
                        CalcValue::Rational(BigRational::new(
                            r1.denom().pow(exp.unsigned_abs()),
                            r1.numer().pow(exp.unsigned_abs()),
                        ))
                    }
                } else {
                    let f_self = self.to_float();
                    let f_other = other.to_float();
                    let res = f_self.powf(f_other);
                    CalcValue::Float(BigDecimal::try_from(res).unwrap_or_default())
                }
            }
            (a, b) => {
                let res = a.to_float().powf(b.to_float());
                CalcValue::Float(BigDecimal::try_from(res).unwrap_or_default())
            }
        }
    }

    /// Negates this `CalcValue`.
    pub fn negate(self) -> CalcValue {
        match self {
            CalcValue::Rational(r) => CalcValue::Rational(-r),
            CalcValue::PiRational(r) => CalcValue::PiRational(-r),
            CalcValue::Float(f) => CalcValue::Float(-f),
        }
    }
}
