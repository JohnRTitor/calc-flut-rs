//! The modular kernel: exact arithmetic in ℤ/nℤ, on `i128`.
//!
//! The algorithms come from `num-modular`. This module owns the parts that
//! crate deliberately leaves to the caller, and each of them is observable:
//!
//! - **Signedness.** The parser produces signed literals and `%` is a signed
//!   operation, so operands are normalised from `i128` here. The crate works in
//!   unsigned types and has no signed modulus at all.
//! - **A zero modulus.** The crate *panics* on it, everywhere, and the release
//!   profile is `panic = "abort"`, so an unguarded call is a process kill on
//!   Android. The convention here: the ring helpers pass their operands through
//!   unreduced, the fallible ones report, because callers rely on getting their
//!   own message about `mod 0`.
//! - **A negative modulus.** Reachable from the workspace's free-text modulus
//!   field. It names the ring of its magnitude, i.e. `rem_euclid(|n|)`.
//! - **Integer width.** `u64` is a large win over `u128` for a modular
//!   multiplier, and every modulus a user types fits in 64 bits. `u128` is
//!   reserved for the wide case, where a double-width intermediate is required
//!   for the result to be exact.
//!
//! Nothing above this module sees any of that.

use crate::modular_arithmetic::error::ModError;
use num_modular::{ModularCoreOps, ModularPow, ModularUnaryOps};

/// The canonical residue of `a` modulo `n`, as an unsigned value in `[0, n)`.
///
/// `ModularAbs::absm` does the same job, but it negates the signed operand,
/// which overflows for `i128::MIN` and panics wherever overflow checks are on.
/// `unsigned_abs` is total, so this conversion is panic-free in every profile.
#[inline]
fn residue(a: i128, n: u128) -> u128 {
    if a >= 0 {
        a as u128 % n
    } else {
        a.unsigned_abs().negm(&n)
    }
}

/// Reduces `a` modulo `n`, ensuring the result is in the range `[0, |n|)`.
pub fn mod_reduce(a: i128, n: i128) -> i128 {
    if n == 0 {
        return a;
    }
    a.rem_euclid(n.unsigned_abs() as i128)
}

// The next three share a shape, and share a contract: a zero modulus is not an
// error here, the operands are combined unreduced. `mod_reduce(a, 0) == a` is
// what makes that pass-through read the way it does.

/// Adds `a` and `b` modulo `n`.
pub fn mod_add(a: i128, b: i128, n: i128) -> i128 {
    if n == 0 {
        return mod_reduce(a, n) + mod_reduce(b, n);
    }
    let un = n.unsigned_abs();
    let (ua, ub) = (residue(a, un), residue(b, un));
    if un <= u64::MAX as u128 {
        (ua as u64).addm(ub as u64, &(un as u64)) as i128
    } else {
        ua.addm(ub, &un) as i128
    }
}

/// Subtracts `b` from `a` modulo `n`.
pub fn mod_sub(a: i128, b: i128, n: i128) -> i128 {
    if n == 0 {
        return mod_reduce(a, n) - mod_reduce(b, n);
    }
    let un = n.unsigned_abs();
    let (ua, ub) = (residue(a, un), residue(b, un));
    if un <= u64::MAX as u128 {
        (ua as u64).subm(ub as u64, &(un as u64)) as i128
    } else {
        ua.subm(ub, &un) as i128
    }
}

/// Multiplies `a` and `b` modulo `n`.
pub fn mod_mul(a: i128, b: i128, n: i128) -> i128 {
    if n == 0 {
        return mod_reduce(a, n) * mod_reduce(b, n);
    }
    let un = n.unsigned_abs();
    let (ua, ub) = (residue(a, un), residue(b, un));
    // The two reduced operands are both below `n`, so their product needs
    // `n^2` of room. `u128` carries the product in a double-width intermediate
    // rather than wrapping, which is the whole reason this module moved off a
    // hand-rolled `i128` multiply.
    if un <= u64::MAX as u128 {
        (ua as u64).mulm(ub as u64, &(un as u64)) as i128
    } else {
        ua.mulm(ub, &un) as i128
    }
}

/// Negates `a` modulo `n`.
pub fn mod_neg(a: i128, n: i128) -> i128 {
    if n == 0 {
        // The zero-modulus pass-through, negated. `wrapping_neg` rather than
        // `-a`, so this branch cannot itself overflow at `i128::MIN`.
        return a.wrapping_neg();
    }
    let un = n.unsigned_abs();
    residue(a, un).negm(&un) as i128
}

/// `base^exp mod m`, narrowed to `u64` when it can be.
///
/// A `u64` modular multiplier uses a 128-bit intermediate where `u128` needs a
/// 256-bit one, so the narrow path is roughly twice the speed. It is only
/// available when *both* the modulus and the exponent fit: narrowing the
/// modulus alone is sound, because every operand is already below it, but
/// narrowing a wide exponent would drop its high bits.
#[inline]
fn powm_in(base: u128, exp: u128, m: u128) -> u128 {
    if m <= u64::MAX as u128 && exp <= u64::MAX as u128 {
        (base as u64).powm(exp as u64, &(m as u64)) as u128
    } else {
        base.powm(exp, &m)
    }
}

/// Computes `base` raised to the power `exp` modulo `modulus`.
///
/// A negative exponent means the base has to be a unit, so it is inverted first
/// and the exponent flipped. `num-modular` has no signed exponents, so this is
/// the one part of the exponent contract the module owns.
pub fn mod_pow(base: i128, exp: i128, modulus: i128) -> Result<i128, ModError> {
    if modulus <= 0 {
        return Err(ModError::InvalidModulus(
            "Modulus must be positive".to_string(),
        ));
    }
    if modulus == 1 {
        return Ok(0);
    }

    let un = modulus as u128;
    let mut ubase = residue(base, un);
    let mut uexp = exp as u128;
    if exp < 0 {
        ubase = ubase.invm(&un).ok_or_else(|| {
            ModError::InverseDoesNotExist(format!("{} and {} are not coprime", base, modulus))
        })?;
        uexp = exp.unsigned_abs();
    }

    Ok(powm_in(ubase, uexp, un) as i128)
}

/// Computes the modular inverse of `a` modulo `n`.
///
/// Refused exactly when `a` is not a unit of ℤ/|n|ℤ, which is also the only
/// case in which the inverse does not exist.
pub fn mod_inv(a: i128, n: i128) -> Result<i128, ModError> {
    if n == 0 {
        return Err(ModError::InverseDoesNotExist(format!(
            "{} and {} are not coprime",
            a, n
        )));
    }
    let un = n.unsigned_abs();
    residue(a, un)
        .invm(&un)
        .map(|inv| inv as i128)
        .ok_or_else(|| ModError::InverseDoesNotExist(format!("{} and {} are not coprime", a, n)))
}

/// Divides `a` by `b` modulo `n`.
pub fn mod_div(a: i128, b: i128, n: i128) -> Result<i128, ModError> {
    let inv_b = mod_inv(b, n)?;
    Ok(mod_mul(a, inv_b, n))
}

/// Determines if a number is prime using trial division and Miller-Rabin.
///
/// `num-modular` has no primality test, so the structure is local; only the
/// witness exponentiation comes from the crate, via `powm_in`.
pub fn is_prime(n: i128) -> bool {
    if n <= 1 {
        return false;
    }
    if n <= 3 {
        return true;
    }
    if n % 2 == 0 || n % 3 == 0 {
        return false;
    }

    // Trial division for small primes
    let mut i = 5;
    while i * i <= n.min(10000) {
        if n % i == 0 || n % (i + 2) == 0 {
            return false;
        }
        i += 6;
    }

    if n <= 10000 {
        return true;
    }

    // Miller-Rabin for larger numbers
    let un = n as u128;
    let mut d = un - 1;
    let mut s = 0;
    while d.is_multiple_of(2) {
        d /= 2;
        s += 1;
    }

    let bases: [u128; 12] = [2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37];
    for &a in &bases {
        if un <= a {
            break;
        }
        let mut x = powm_in(a, d, un);
        if x == 1 || x == un - 1 {
            continue;
        }
        let mut composite = true;
        for _ in 1..s {
            x = powm_in(x, 2, un);
            if x == un - 1 {
                composite = false;
                break;
            }
        }
        if composite {
            return false;
        }
    }

    true
}
