use crate::modular_arithmetic::{
    mod_arith::{is_prime, mod_pow},
    number_theory::gcd,
};

#[derive(Debug, Clone)]
pub struct RingInfo {
    pub n: i128,
    pub classification: String,
    pub is_integral_domain: bool,
    pub is_field: bool,
    pub units_count: i128,
    pub units: Vec<i128>,
    pub zero_divisors_count: i128,
    pub zero_divisors: Vec<i128>,
    pub idempotents_count: i128,
    pub idempotents: Vec<i128>,
    pub nilpotents_count: i128,
    pub nilpotents: Vec<i128>,
    pub is_truncated: bool,
}

/// Returns the zero divisors in Z_n, up to a limit.
pub fn zero_divisors_limited(n: i128, limit: usize) -> Vec<i128> {
    let mut zd = Vec::new();
    let n = n.abs();
    if n <= 1 {
        return zd;
    }
    for i in 1..n {
        let g = gcd(i, n);
        if g > 1 && g < n {
            zd.push(i);
            if zd.len() >= limit {
                break;
            }
        }
    }
    zd
}

/// Returns pairs of zero divisors (a,b) where a*b = 0 mod n.
/// It returns one pair for each zero divisor a.
pub fn zero_divisor_pairs(n: i128) -> Vec<(i128, i128)> {
    let mut pairs = Vec::new();
    let n = n.abs();
    if n <= 1 {
        return pairs;
    }
    for i in 1..n {
        let g = gcd(i, n);
        if g > 1 && g < n {
            let b = n / g; // i * (n/g) = (i/g) * n == 0 mod n
            pairs.push((i, b));
        }
    }
    pairs
}

/// Returns the idempotent elements of Z_n, up to a limit.
pub fn idempotents_limited(n: i128, limit: usize) -> Vec<i128> {
    let mut idemp = Vec::new();
    let n = n.abs();
    if n <= 1 {
        return idemp;
    }
    for i in 0..n {
        if mod_pow(i, 2, n).unwrap_or(0) == i {
            idemp.push(i);
            if idemp.len() >= limit {
                break;
            }
        }
    }
    idemp
}

/// Returns the nilpotent elements of Z_n, up to a limit.
pub fn nilpotents_limited(n: i128, limit: usize) -> Vec<i128> {
    let mut nilp = Vec::new();
    let n = n.abs();
    if n <= 1 {
        return nilp;
    }

    let factors = crate::modular_arithmetic::number_theory_ext::prime_factorization(n);
    let mut product_of_primes = 1;
    for (p, _) in factors {
        product_of_primes *= p;
    }

    for i in 0..n {
        if i % product_of_primes == 0 {
            nilp.push(i);
            if nilp.len() >= limit {
                break;
            }
        }
    }
    nilp
}

/// Classifies the ring Z_n.
pub fn ring_classify(n: i128) -> RingInfo {
    let is_p = is_prime(n);
    let class_str = if is_p {
        "Finite Field (Galois Field)"
    } else if n == 1 {
        "Trivial Ring"
    } else {
        "Commutative Ring with Unity"
    };

    let limit = 10000;
    let factors = crate::modular_arithmetic::number_theory_ext::prime_factorization(n);
    let mut product_of_primes = 1;
    let mut distinct_primes = 0;
    for (p, _) in &factors {
        product_of_primes *= p;
        distinct_primes += 1;
    }

    let units_count = crate::modular_arithmetic::number_theory_ext::euler_totient(n);
    let zero_divisors_count = if n > 1 { n - 1 - units_count } else { 0 };
    let idempotents_count = if n > 1 { 1i128 << distinct_primes } else { 0 };
    let nilpotents_count = if n > 1 { n / product_of_primes } else { 0 };

    let mut units = Vec::new();
    for i in 1..n {
        if gcd(i, n) == 1 {
            units.push(i);
            if units.len() >= limit {
                break;
            }
        }
    }

    let zero_divisors = zero_divisors_limited(n, limit);
    let idempotents = idempotents_limited(n, limit);
    let nilpotents = nilpotents_limited(n, limit);

    let is_truncated = units_count > limit as i128
        || zero_divisors_count > limit as i128
        || idempotents_count > limit as i128
        || nilpotents_count > limit as i128;

    RingInfo {
        n,
        classification: class_str.to_string(),
        is_integral_domain: is_p,
        is_field: is_p,
        units_count,
        units,
        zero_divisors_count,
        zero_divisors,
        idempotents_count,
        idempotents,
        nilpotents_count,
        nilpotents,
        is_truncated,
    }
}
