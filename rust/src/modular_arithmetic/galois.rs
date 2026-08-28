use crate::modular_arithmetic::{
    error::ModError,
    mod_arith::{is_prime, mod_add, mod_div, mod_inv, mod_mul, mod_sub},
};

/// Represents an element in the Galois Field GF(p) where p is a prime.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct GFPrime {
    pub value: i128,
    pub p: i128,
}

impl GFPrime {
    /// Creates a new element in GF(p). Returns an error if p is not prime.
    pub fn new(value: i128, p: i128) -> Result<Self, ModError> {
        if p <= 1 {
            return Err(ModError::InvalidModulus(
                "p must be a prime > 1".to_string(),
            ));
        }
        if !is_prime(p) {
            return Err(ModError::NotPrime(format!("{} is not prime", p)));
        }
        Ok(Self {
            value: crate::modular_arithmetic::mod_arith::mod_reduce(value, p),
            p,
        })
    }

    /// Creates a new element without checking primality (for internal use when p is known to be prime).
    pub fn new_unchecked(value: i128, p: i128) -> Self {
        Self {
            value: crate::modular_arithmetic::mod_arith::mod_reduce(value, p),
            p,
        }
    }

    pub fn add(&self, other: &Self) -> Result<Self, ModError> {
        if self.p != other.p {
            return Err(ModError::InvalidExpression(
                "Cannot add elements from different fields".to_string(),
            ));
        }
        Ok(Self::new_unchecked(
            mod_add(self.value, other.value, self.p),
            self.p,
        ))
    }

    pub fn sub(&self, other: &Self) -> Result<Self, ModError> {
        if self.p != other.p {
            return Err(ModError::InvalidExpression(
                "Cannot subtract elements from different fields".to_string(),
            ));
        }
        Ok(Self::new_unchecked(
            mod_sub(self.value, other.value, self.p),
            self.p,
        ))
    }

    pub fn mul(&self, other: &Self) -> Result<Self, ModError> {
        if self.p != other.p {
            return Err(ModError::InvalidExpression(
                "Cannot multiply elements from different fields".to_string(),
            ));
        }
        Ok(Self::new_unchecked(
            mod_mul(self.value, other.value, self.p),
            self.p,
        ))
    }

    pub fn inv(&self) -> Result<Self, ModError> {
        if self.value == 0 {
            return Err(ModError::DivisionByZero);
        }
        let inv = mod_inv(self.value, self.p)?;
        Ok(Self::new_unchecked(inv, self.p))
    }

    pub fn div(&self, other: &Self) -> Result<Self, ModError> {
        if self.p != other.p {
            return Err(ModError::InvalidExpression(
                "Cannot divide elements from different fields".to_string(),
            ));
        }
        if other.value == 0 {
            return Err(ModError::DivisionByZero);
        }
        let div = mod_div(self.value, other.value, self.p)?;
        Ok(Self::new_unchecked(div, self.p))
    }
}
