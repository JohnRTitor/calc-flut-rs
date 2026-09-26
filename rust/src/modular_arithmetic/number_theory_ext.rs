use {
    crate::modular_arithmetic::{
        error::ModError,
        mod_arith::{is_prime, mod_pow, mod_reduce},
        number_theory::{extended_gcd, gcd},
    },
    std::collections::HashMap,
};

/// The largest trial divisor `prime_factorization` will reach before it gives up.
///
/// Trial division is O(√n) in the worst case, which is a prime. Measured on this
/// crate's kernel, that is ~3 ns per odd divisor, so a 2^61 modulus takes 2.2 s
/// and an `i128` modulus can be 2^127 — where the same loop would run for
/// something like 10^10 years. On a `#[frb(sync)]` call that is not a slow
/// answer, it is a frozen platform thread and eventually an ANR.
///
/// The primality short-circuit below means a large *prime* never approaches this
/// bound, which is the case a user actually reaches by typing a big number into a
/// modulus field. What runs out of budget is a composite with no factor below the
/// bound — the one case where patience would not have helped either.
pub const MAX_TRIAL_DIVISOR: i128 = 10_000_000;

/// The largest modulus any path in this module will *enumerate*.
///
/// Several of these functions walk the ring, so their cost is set by the modulus
/// rather than by the arithmetic. The `*_limited` family looked bounded because it
/// stopped at a limit — but the limit was on the output, and the scan behind it
/// kept going. A prime is the pathological case for three of them at once: it has
/// no zero divisors, exactly two idempotents and one nilpotent, so none of them
/// ever reaches its limit and each walks all `n` elements, `n` being up to 2^127.
///
/// Measured on this crate's kernel, one million steps costs 20–60 ms, so this
/// keeps every enumeration inside a couple of frames. It is a scan ceiling, not a
/// correctness limit: the counts a caller reports alongside come from arithmetic
/// and stay exact past it.
pub const MAX_SCAN: i128 = 1_000_000;

/// The largest enumeration this module will return whole.
///
/// Distinct from [`MAX_SCAN`]: these results are rendered as one comma-joined
/// string and cross the FFI boundary, so a million entries is a payload problem
/// rather than a time one. Matches the limit the bridge already applies when it
/// decides whether to attach a Cayley table.
pub const MAX_LISTED: i128 = 10_000;

/// Returns the prime factorization of n as a list of (prime, exponent).
///
/// Refuses rather than returning a partial factorization. Every consumer here
/// derives from the *complete* list — φ, element order, the nilpotent count — so
/// a truncated one would be silently wrong in a way no caller could detect.
pub fn prime_factorization(n: i128) -> Result<Vec<(i128, u32)>, ModError> {
    let Some(mut rest) = n.checked_abs() else {
        return Err(ModError::TooLarge(format!(
            "{n} has no representable absolute value"
        )));
    };
    let mut factors: Vec<(i128, u32)> = Vec::new();
    if rest <= 1 {
        return Ok(factors);
    }

    // Ask before starting: primality decides the expensive case immediately, and
    // a large prime is the input a user is most likely to type.
    if is_prime(rest) {
        return Ok(vec![(rest, 1)]);
    }

    let mut count = 0;
    while rest % 2 == 0 {
        count += 1;
        rest /= 2;
    }
    if count > 0 {
        factors.push((2, count));
    }

    // Bounding `i` also bounds `i * i`, which otherwise overflows an i128 for a
    // modulus above 2^63 and turns the loop condition into nonsense.
    let mut i = 3;
    while i <= MAX_TRIAL_DIVISOR && i * i <= rest {
        let mut count = 0;
        while rest % i == 0 {
            count += 1;
            rest /= i;
        }
        if count > 0 {
            factors.push((i, count));
            // The remainder just shrank, so it may be prime now. Asking here is
            // what keeps 3 * 5 * (a large prime) instant instead of walking the
            // rest of the bound finding nothing.
            if rest > 1 && is_prime(rest) {
                factors.push((rest, 1));
                return Ok(factors);
            }
        }
        i += 2;
    }

    if rest > 1 {
        // Reaching here means either trial division ran all the way to √rest, in
        // which case rest is prime and the loop says so, or the budget ran out
        // with rest still composite. Only the first may be reported.
        if !is_prime(rest) {
            return Err(ModError::TooLarge(format!(
                "{} has no factor at or below {} and is too large to factor by trial division",
                rest, MAX_TRIAL_DIVISOR
            )));
        }
        factors.push((rest, 1));
    }

    Ok(factors)
}

/// Computes Euler's totient function φ(n).
pub fn euler_totient(n: i128) -> Result<i128, ModError> {
    let Some(n) = n.checked_abs() else {
        return Err(ModError::TooLarge(format!(
            "{n} has no representable absolute value"
        )));
    };
    if n == 0 {
        return Ok(0);
    }
    let mut result = n;
    for (p, _) in prime_factorization(n)? {
        result -= result / p;
    }
    Ok(result)
}

/// Computes the order of element a modulo n. Returns Err if gcd(a,n) > 1.
pub fn element_order(a: i128, n: i128) -> Result<i128, ModError> {
    if n <= 1 {
        return Err(ModError::InvalidModulus("Modulus must be > 1".to_string()));
    }
    let a_reduced = mod_reduce(a, n);
    if gcd(a_reduced, n) != 1 {
        return Err(ModError::InvalidExpression(format!(
            "Order undefined: gcd({}, {}) != 1",
            a_reduced, n
        )));
    }

    let phi = euler_totient(n)?;
    let mut order = phi;
    let factors = prime_factorization(phi)?;

    // For each prime factor p of phi, if a^(phi/p) == 1, then the order divides phi/p.
    for (p, _) in factors {
        let mut temp = order;
        while temp % p == 0 && mod_pow(a_reduced, temp / p, n)? == 1 {
            temp /= p;
        }
        order = temp;
    }

    Ok(order)
}

/// Checks if a is a primitive root modulo n.
pub fn is_primitive_root(a: i128, n: i128) -> Result<bool, ModError> {
    if gcd(a, n) != 1 {
        return Ok(false);
    }
    let order = element_order(a, n)?;
    let phi = euler_totient(n)?;
    Ok(order == phi)
}

/// Helper to check if n has primitive roots. They exist iff n is 1, 2, 4, p^k, or 2*p^k for odd prime p.
pub fn has_primitive_roots(n: i128) -> Result<bool, ModError> {
    let n = n
        .checked_abs()
        .ok_or_else(|| ModError::TooLarge(format!("{n} has no representable absolute value")))?;
    if n == 1 || n == 2 || n == 4 {
        return Ok(true);
    }
    let mut m = n;
    if m % 2 == 0 {
        m /= 2;
        if m % 2 == 0 {
            return Ok(false); // divisible by 4, and n > 4
        }
    }
    // Now m must be p^k for some odd prime p
    let factors = prime_factorization(m)?;
    Ok(factors.len() == 1)
}

/// Returns all primitive roots modulo n.
pub fn primitive_roots(n: i128) -> Result<Vec<i128>, ModError> {
    if n <= 1 {
        return Err(ModError::InvalidModulus("Modulus must be > 1".to_string()));
    }
    if !has_primitive_roots(n)? {
        return Err(ModError::NoPrimitiveRoot(format!(
            "Z_{}* is not cyclic (no primitive roots exist)",
            n
        )));
    }

    let mut roots = Vec::new();
    let phi = euler_totient(n)?;

    // Find the first primitive root
    let mut g = -1;
    for i in 2..n {
        if gcd(i, n) == 1 && is_primitive_root(i, n)? {
            g = i;
            break;
        }
    }

    if g == -1 {
        return Err(ModError::NoPrimitiveRoot(format!(
            "Could not find primitive root for {}",
            n
        )));
    }

    // The other primitive roots are g^k mod n where gcd(k, phi) == 1
    for k in 1..phi {
        if gcd(k, phi) == 1 {
            roots.push(mod_pow(g, k, n)?);
        }
    }

    roots.sort_unstable();
    Ok(roots)
}

/// Returns the cyclic subgroup generated by a modulo n.
pub fn cyclic_subgroup(a: i128, n: i128) -> Result<Vec<i128>, ModError> {
    if n <= 1 {
        return Err(ModError::InvalidModulus("Modulus must be > 1".to_string()));
    }
    let a_red = mod_reduce(a, n);
    let mut subgroup = Vec::new();
    let mut current = 1;

    // Keep multiplying by a until we hit a cycle or 0
    let mut seen = std::collections::HashSet::new();

    loop {
        if seen.contains(&current) {
            break;
        }
        seen.insert(current);
        subgroup.push(current);
        current = mod_reduce(current * a_red, n);
    }

    subgroup.sort_unstable();
    Ok(subgroup)
}

/// Returns the unit group Z_n* (elements coprime to n).
///
/// Refused above [`MAX_LISTED`]. The whole group is rendered as one
/// comma-joined string for display, so there is no partial answer worth giving:
/// a truncated group that still called itself Z_n* would be worse than a
/// message. Callers that want a count should use `euler_totient`, which is
/// arithmetic and exact for any modulus.
pub fn unit_group(n: i128) -> Result<Vec<i128>, ModError> {
    let Some(n) = n.checked_abs() else {
        return Err(ModError::TooLarge(format!(
            "{n} has no representable absolute value"
        )));
    };
    let mut units = Vec::new();
    if n <= 1 {
        return Ok(units);
    }
    if n > MAX_LISTED {
        return Err(ModError::TooLarge(format!(
            "Z_{n}* has too many elements to list; the limit is {MAX_LISTED}. Use phi({n}) for the count."
        )));
    }
    for i in 1..n {
        if gcd(i, n) == 1 {
            units.push(i);
        }
    }
    Ok(units)
}

/// Returns the additive inverse of a modulo n.
pub fn additive_inverse(a: i128, n: i128) -> i128 {
    let a_red = mod_reduce(a, n);
    if a_red == 0 { 0 } else { n - a_red }
}

/// Solves ax ≡ b (mod n). Returns all distinct solutions mod n.
pub fn solve_linear_congruence(a: i128, b: i128, n: i128) -> Result<Vec<i128>, ModError> {
    if n <= 0 {
        return Err(ModError::InvalidModulus(
            "Modulus must be positive".to_string(),
        ));
    }
    let a_red = mod_reduce(a, n);
    let b_red = mod_reduce(b, n);

    let (g, x, _) = extended_gcd(a_red, n);
    if b_red % g != 0 {
        return Err(ModError::NoSolution(format!(
            "No solution: {} does not divide {}",
            g, b_red
        )));
    }

    let mut solutions = Vec::new();
    let x0 = mod_reduce(x * (b_red / g), n);

    let step = n / g;
    for i in 0..g {
        solutions.push(mod_reduce(x0 + i * step, n));
    }

    solutions.sort_unstable();
    Ok(solutions)
}

/// Computes the discrete logarithm x such that base^x ≡ target (mod p).
/// Uses the Baby-step Giant-step algorithm.
/// Caps at p <= 1_000_000_000 for performance limits.
pub fn discrete_log(base: i128, target: i128, p: i128) -> Result<i128, ModError> {
    if p <= 1 {
        return Err(ModError::InvalidModulus("Modulus must be > 1".to_string()));
    }
    if p > 1_000_000_000 {
        return Err(ModError::TooLarge(format!(
            "Modulus {} is too large for discrete log. Limit is 10^9.",
            p
        )));
    }
    let a = mod_reduce(base, p);
    let b = mod_reduce(target, p);

    // Special cases
    if b == 1 {
        return Ok(0);
    }
    if a == 0 {
        return if b == 0 {
            Ok(1)
        } else {
            Err(ModError::NoSolution(format!(
                "No solution for 0^x = {} mod {}",
                b, p
            )))
        };
    }

    // Baby-step Giant-step
    let m = (p as f64).sqrt().ceil() as i128;

    let mut table = HashMap::new();
    let mut current = 1;
    for j in 0..m {
        // Store the earliest j
        table.entry(current).or_insert(j);
        current = mod_reduce(current * a, p);
    }

    let factor = mod_pow(crate::modular_arithmetic::mod_arith::mod_inv(a, p)?, m, p)?;

    current = b;
    for i in 0..m {
        if let Some(&j) = table.get(&current) {
            return Ok(i * m + j);
        }
        current = mod_reduce(current * factor, p);
    }

    Err(ModError::NoSolution(format!(
        "No discrete log found for {}^x = {} mod {}",
        a, b, p
    )))
}
