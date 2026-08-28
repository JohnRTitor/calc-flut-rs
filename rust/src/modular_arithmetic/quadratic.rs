use crate::modular_arithmetic::{
    error::ModError,
    mod_arith::{is_prime, mod_pow, mod_reduce},
};

/// Returns the quadratic residues modulo n.
pub fn quadratic_residues(n: i128) -> Vec<i128> {
    let mut residues = std::collections::HashSet::new();
    let n = n.abs();
    if n <= 1 {
        return vec![];
    }

    // 0 is typically excluded or included depending on definition. We will include it.
    for i in 0..n {
        residues.insert(mod_reduce(i * i, n));
    }

    let mut result: Vec<i128> = residues.into_iter().collect();
    result.sort_unstable();
    result
}

/// Checks if a is a quadratic residue modulo n.
pub fn is_quadratic_residue(a: i128, n: i128) -> bool {
    let a_red = mod_reduce(a, n);
    let residues = quadratic_residues(n);
    residues.contains(&a_red)
}

/// Computes the Legendre symbol (a/p).
/// Returns 1 if a is a QR mod p, -1 if a is a QNR mod p, and 0 if a ≡ 0 mod p.
pub fn legendre_symbol(a: i128, p: i128) -> Result<i8, ModError> {
    if p <= 2 || !is_prime(p) {
        return Err(ModError::InvalidModulus(
            "Legendre symbol requires an odd prime modulus".to_string(),
        ));
    }
    let a_red = mod_reduce(a, p);
    if a_red == 0 {
        return Ok(0);
    }

    let l = mod_pow(a_red, (p - 1) / 2, p)?;
    if l == p - 1 { Ok(-1) } else { Ok(1) }
}

/// Computes the Jacobi symbol (a/n).
pub fn jacobi_symbol(mut a: i128, mut n: i128) -> Result<i8, ModError> {
    if n <= 0 || n % 2 == 0 {
        return Err(ModError::InvalidModulus(
            "Jacobi symbol requires an odd positive modulus".to_string(),
        ));
    }

    a = mod_reduce(a, n);
    let mut t = 1;

    while a != 0 {
        while a % 2 == 0 {
            a /= 2;
            let r = n % 8;
            if r == 3 || r == 5 {
                t = -t;
            }
        }

        std::mem::swap(&mut a, &mut n);

        if a % 4 == 3 && n % 4 == 3 {
            t = -t;
        }

        a %= n;
    }

    if n == 1 { Ok(t) } else { Ok(0) }
}

/// Computes modular square roots using the Tonelli-Shanks algorithm.
/// Finds all r such that r^2 = a (mod p) where p is prime.
pub fn sqrt_mod(a: i128, p: i128) -> Result<Vec<i128>, ModError> {
    if p <= 1 || !is_prime(p) {
        return Err(ModError::NotPrime(format!(
            "{} is not prime. Tonelli-Shanks requires a prime modulus.",
            p
        )));
    }

    let a = mod_reduce(a, p);
    if a == 0 {
        return Ok(vec![0]);
    }

    if p == 2 {
        return Ok(vec![a]);
    }

    if legendre_symbol(a, p)? != 1 {
        return Err(ModError::NoSolution(format!(
            "{} is not a quadratic residue modulo {}",
            a, p
        )));
    }

    let mut q = p - 1;
    let mut s = 0;
    while q % 2 == 0 {
        q /= 2;
        s += 1;
    }

    let mut z = 2;
    while legendre_symbol(z, p)? != -1 {
        z += 1;
    }

    let mut m = s;
    let mut c = mod_pow(z, q, p)?;
    let mut t = mod_pow(a, q, p)?;
    let mut r = mod_pow(a, (q + 1) / 2, p)?;

    loop {
        if t == 0 {
            return Ok(vec![0]);
        }
        if t == 1 {
            let mut roots = vec![r, p - r];
            roots.sort_unstable();
            roots.dedup();
            return Ok(roots);
        }

        let mut t2 = t;
        let mut i = 0;
        for j in 1..m {
            t2 = mod_pow(t2, 2, p)?;
            if t2 == 1 {
                i = j;
                break;
            }
        }

        if i == 0 {
            return Err(ModError::NoSolution(
                "Failed to find modular square root".to_string(),
            ));
        }

        let b = mod_pow(c, 1_i128 << (m - i - 1), p)?;
        m = i;
        c = mod_pow(b, 2, p)?;
        t = mod_reduce(t * c, p);
        r = mod_reduce(r * b, p);
    }
}
