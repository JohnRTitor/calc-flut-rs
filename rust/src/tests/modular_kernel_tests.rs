//! Tests for the numeric kernel under `modular_arithmetic/`.
//!
//! These exercise the arithmetic itself — residues, inverses, powers, primality
//! and the quadratic symbols — rather than the shape of a bridge response.
//!
//! The randomised sections check the kernel against exact `BigInt` arithmetic
//! and against mathematical identities, never against a second copy of the
//! same algorithm, so they fail when the kernel is wrong rather than when it
//! merely changes.

#[cfg(test)]
mod tests {
    use crate::modular_arithmetic::{
        error::ModError,
        mod_arith::{
            is_prime, mod_add, mod_div, mod_inv, mod_mul, mod_neg, mod_pow, mod_reduce, mod_sub,
        },
        quadratic::{jacobi_symbol, legendre_symbol},
    };
    use num_bigint::BigInt;

    // ---------------------------------------------------------------------
    // Exact reference arithmetic
    // ---------------------------------------------------------------------

    /// `x` reduced into `[0, n)`, for `n > 0`.
    ///
    /// `BigInt`'s `%` takes the sign of the dividend, so the sign is corrected
    /// here. This is `Integer::mod_floor`, written out rather than pulled in as
    /// a dependency for one line.
    fn floor_rem(x: &BigInt, n: i128) -> BigInt {
        let bn = BigInt::from(n);
        (x % &bn + &bn) % &bn
    }

    /// `x` reduced into `[0, n)`, narrowed to `i128`. Used where the reference
    /// expression itself — `ra + rb`, say — is too wide for an `i128`.
    fn exact_rem_wide(x: &BigInt, n: i128) -> i128 {
        floor_rem(x, n).to_string().parse().unwrap()
    }

    /// `x` reduced into `[0, n)`, as an `i128` operand for the kernel.
    fn exact_rem(x: &BigInt, n: i128) -> i128 {
        exact_rem_wide(x, n)
    }

    /// Asserts on the rendered error rather than on the error value, so these
    /// tests pin the message a user actually sees without `PartialEq` having to
    /// be derived on a public error type for testing's sake.
    #[track_caller]
    fn assert_value(res: Result<i128, ModError>, want: i128) {
        match res {
            Ok(got) => assert_eq!(got, want),
            Err(e) => panic!("expected {want}, got error: {e}"),
        }
    }

    #[track_caller]
    fn assert_message(res: Result<i128, ModError>, want: &str) {
        match res {
            Ok(got) => panic!("expected error {want:?}, got {got}"),
            Err(e) => assert_eq!(e.to_string(), want),
        }
    }

    /// Greatest common divisor, written out here so the inverse tests do not
    /// lean on the implementation they are checking.
    fn gcd(mut a: i128, mut b: i128) -> i128 {
        a = a.unsigned_abs() as i128;
        b = b.unsigned_abs() as i128;
        while b != 0 {
            let t = b;
            b = a % b;
            a = t;
        }
        a
    }

    /// Deterministic PRNG. A fixed seed keeps a failure reproducible, which a
    /// wall-clock or entropy source would not.
    struct Rng(u128);

    impl Rng {
        fn next(&mut self) -> u128 {
            let mut x = self.0;
            let y = x.wrapping_mul(0x2360_ED05_1FC6_5DA4_4385_DF64_9FCC_F645);
            x = y ^ (y >> 31);
            x = x.wrapping_mul(0x9E37_79B9_7F4A_7C15);
            x ^= x >> 27;
            self.0 = x;
            x ^ (x >> 33) ^ y
        }

        /// A modulus of at most `bits` bits, and never zero.
        fn modulus(&mut self, bits: u32) -> i128 {
            (self.next() % (1u128 << bits)).max(1) as i128
        }
    }

    // ---------------------------------------------------------------------
    // mod_reduce
    // ---------------------------------------------------------------------

    #[test]
    fn reduce_lands_in_the_canonical_range() {
        for n in [1i128, 2, 3, 5, 7, 12, 1_000_000_007] {
            for a in [-25i128, -7, -1, 0, 1, 6, 7, 25] {
                let r = mod_reduce(a, n);
                assert!((0..n).contains(&r), "{a} mod {n} gave {r}");
            }
        }
    }

    #[test]
    fn reduce_handles_negative_values_and_negative_moduli() {
        assert_eq!(mod_reduce(-1, 5), 4);
        assert_eq!(mod_reduce(-6, 5), 4);
        assert_eq!(mod_reduce(6, 5), 1);
        assert_eq!(mod_reduce(-7, 7), 0);
        // A negative modulus gives the ring of its magnitude, which the
        // workspace's free-text modulus field lets a user reach.
        assert_eq!(mod_reduce(6, -5), 1);
        assert_eq!(mod_reduce(-6, -5), 4);
        assert_eq!(mod_reduce(6, -5), mod_reduce(6, 5));
    }

    #[test]
    fn reduce_survives_the_extremes_of_i128() {
        assert_eq!(
            mod_reduce(i128::MAX, 1_000_000_007),
            i128::MAX % 1_000_000_007
        );
        assert_eq!(
            mod_reduce(i128::MIN, 1_000_000_007),
            exact_rem_wide(&BigInt::from(i128::MIN), 1_000_000_007)
        );
        // |n| == 2^127 has no positive i128 form; the residue still has to come
        // back non-negative.
        assert_eq!(mod_reduce(i128::MIN, i128::MIN), 0);
        assert!(mod_reduce(-3, i128::MIN) >= 0);
    }

    /// A zero modulus is not an error: the operand passes straight through.
    /// Callers rely on getting their own complaint about `mod 0`, so this must
    /// not become a panic.
    #[test]
    fn reduce_passes_the_operand_through_for_a_zero_modulus() {
        assert_eq!(mod_reduce(5, 0), 5);
        assert_eq!(mod_reduce(-5, 0), -5);
        assert_eq!(mod_reduce(0, 0), 0);
        assert_eq!(mod_reduce(i128::MIN, 0), i128::MIN);
    }

    #[test]
    fn reduce_matches_rem_euclid_over_the_whole_input_space() {
        for n in -40i128..=40 {
            if n == 0 {
                continue;
            }
            for a in -200i128..=200 {
                assert_eq!(
                    mod_reduce(a, n),
                    a.rem_euclid(n.unsigned_abs() as i128),
                    "{a} mod {n}"
                );
            }
        }
    }

    // ---------------------------------------------------------------------
    // Ring operations
    // ---------------------------------------------------------------------

    #[test]
    fn ring_operations_land_in_the_canonical_range() {
        for n in [1i128, 2, 3, 7, 12, 97, 1_000_000_007] {
            for a in [-30i128, -1, 0, 1, 29] {
                for b in [-30i128, -1, 0, 1, 29] {
                    for r in [mod_add(a, b, n), mod_sub(a, b, n), mod_mul(a, b, n)] {
                        assert!((0..n).contains(&r), "({a}, {b}, {n}) gave {r}");
                    }
                }
            }
        }
    }

    #[test]
    fn ring_operations_agree_with_exact_arithmetic() {
        for n in [1i128, 2, 3, 7, 12, 97, 1_000_000_007, (1 << 62) + 1] {
            for a in [-30i128, -1, 0, 1, 29] {
                for b in [-30i128, -1, 0, 1, 29] {
                    let ra = floor_rem(&BigInt::from(a), n);
                    let rb = floor_rem(&BigInt::from(b), n);
                    assert_eq!(mod_add(a, b, n), exact_rem_wide(&(&ra + &rb), n));
                    assert_eq!(mod_sub(a, b, n), exact_rem_wide(&(&ra - &rb), n));
                    assert_eq!(mod_mul(a, b, n), exact_rem_wide(&(&ra * &rb), n));
                    // Negation is the additive inverse.
                    assert_eq!(mod_neg(a, n), exact_rem_wide(&(&BigInt::from(n) - &ra), n));
                    assert_eq!(mod_add(a, mod_neg(a, n), n), 0);
                }
            }
        }
    }

    #[test]
    fn multiplication_does_not_overflow_above_sixty_four_bits() {
        // Two reduced operands below `n` need `n²` of room, so the product
        // belongs in a double-width intermediate. Multiplying in the operand
        // type instead wraps above about 2^63.5, and the release profile has
        // overflow checks off.
        let n: i128 = 18_446_744_073_709_551_617; // just past 2^64
        let want = exact_rem_wide(&(&BigInt::from(n - 1) * BigInt::from(n - 1)), n);
        assert_eq!(mod_mul(n - 1, n - 1, n), want);
        assert_eq!(mod_mul(n - 1, n - 1, n), 1);
    }

    #[test]
    fn multiplication_is_exact_across_every_small_modulus() {
        for n in 1i128..=300 {
            for &(a, b) in &[(n - 1, n - 1), (n - 1, 1), (1, n - 1), (n / 2, n / 2)] {
                let want = exact_rem_wide(&(&BigInt::from(a) * BigInt::from(b)), n);
                assert_eq!(mod_mul(a, b, n), want, "{a} * {b} mod {n}");
            }
        }
    }

    // ---------------------------------------------------------------------
    // Inverse and division
    // ---------------------------------------------------------------------

    #[test]
    fn inverse_of_a_unit_is_the_multiplicative_identity() {
        for n in [2i128, 3, 5, 7, 11, 97, 1_000_000_007, (1 << 62) + 1] {
            for a in 1i128..n.min(200) {
                match mod_inv(a, n) {
                    Ok(inv) => assert_eq!(mod_mul(a, inv, n), 1 % n, "inv of {a} mod {n}"),
                    // Only ever refused when the value is not a unit.
                    Err(_) => assert_ne!(gcd(a, n), 1, "refused a coprime value: {a} mod {n}"),
                }
            }
        }
    }

    #[test]
    fn inverse_is_refused_exactly_for_non_units() {
        let not_coprime =
            |a: i128, b: i128| format!("Inverse does not exist: {a} and {b} are not coprime");
        assert_value(mod_inv(3, 7), 5);
        assert_message(mod_inv(2, 6), &not_coprime(2, 6));
        assert_message(mod_inv(0, 7), &not_coprime(0, 7));
        assert_message(mod_inv(5, 5), &not_coprime(5, 5));
        assert_message(mod_inv(6, 9), &not_coprime(6, 9));
        // Negative operands reduce first, so they are the same units.
        assert_value(mod_inv(-3, 7), 2);
        // A negative modulus names the ring of its magnitude.
        assert_value(mod_inv(3, -7), 5);
        // The trivial ring has one element, which is its own inverse.
        assert_value(mod_inv(1, 1), 0);
    }

    #[test]
    fn inverse_and_division_refuse_a_zero_modulus() {
        assert!(mod_inv(3, 0).is_err());
        assert!(mod_div(3, 2, 0).is_err());
    }

    #[test]
    fn division_is_multiplication_by_the_inverse() {
        for n in [2i128, 3, 5, 7, 11, 97, 1_000_000_007] {
            for a in 0..n.min(50) {
                for b in 1..n.min(50) {
                    // Both sides must agree on *whether* the division happened,
                    // so compare the rendered outcome rather than the value.
                    let (actual, expected) = match (mod_div(a, b, n), mod_inv(b, n)) {
                        (Ok(q), Ok(inv)) => (q.to_string(), mod_mul(a, inv, n).to_string()),
                        (Err(e), Err(f)) => (e.to_string(), f.to_string()),
                        (Ok(q), Err(_)) => panic!("divided by a non-unit: {a} / {b} mod {n} = {q}"),
                        (Err(e), Ok(_)) => panic!("refused a unit: {a} / {b} mod {n}: {e}"),
                    };
                    assert_eq!(actual, expected, "{a} / {b} mod {n}");
                }
            }
        }
    }

    #[test]
    fn division_refuses_a_non_invertible_divisor() {
        assert!(mod_div(1, 2, 6).is_err());
        assert!(mod_div(1, 0, 7).is_err());
    }

    // ---------------------------------------------------------------------
    // Exponentiation
    // ---------------------------------------------------------------------

    #[test]
    fn power_covers_the_exponent_edges() {
        assert_eq!(mod_pow(2, 0, 7).unwrap(), 1);
        assert_eq!(mod_pow(0, 0, 7).unwrap(), 1);
        assert_eq!(mod_pow(0, 5, 7).unwrap(), 0);
        assert_eq!(mod_pow(2, 1, 7).unwrap(), 2);
        assert_eq!(mod_pow(2, 2, 7).unwrap(), 4);
        assert_eq!(mod_pow(7, 3, 7).unwrap(), 0);
        assert_eq!(mod_pow(-2, 3, 7).unwrap(), 6);
        // Modulus one collapses everything, a zero exponent included.
        assert_eq!(mod_pow(5, 0, 1).unwrap(), 0);
        assert_eq!(mod_pow(5, 9, 1).unwrap(), 0);
    }

    #[test]
    fn power_handles_an_exponent_wider_than_the_modulus() {
        // A 100-bit exponent is reduced by repeated squaring, never
        // materialised. Checked against exact arithmetic rather than by
        // reducing the exponent modulo a group order, which would make the test
        // a statement about the order rather than about the kernel.
        let m = 1_000_000_007i128;
        for huge in [(1i128 << 100) + 7, i128::MAX, 1 << 64, (1 << 96) - 1] {
            let want = BigInt::from(2)
                .modpow(&BigInt::from(huge), &BigInt::from(m))
                .to_string()
                .parse::<i128>()
                .unwrap();
            assert_eq!(mod_pow(2, huge, m).unwrap(), want, "2^{huge} mod {m}");
        }
    }

    #[test]
    fn power_keeps_an_exponent_wider_than_64_bits() {
        // The kernel narrows to a 64-bit exponent when it can. It must not do
        // that when the exponent does not fit, and it must not do it by
        // truncating: the modulus here is small enough to take the narrow path
        // on its own, so only the exponent decides.
        let m = 1_000_000_007i128;
        for e in [
            1i128 << 63,
            (1i128 << 64) - 1,
            1i128 << 64,
            (1i128 << 64) + 1,
            1i128 << 100,
            i128::MAX,
        ] {
            let want = BigInt::from(2)
                .modpow(&BigInt::from(e), &BigInt::from(m))
                .to_string()
                .parse::<i128>()
                .unwrap();
            assert_eq!(mod_pow(2, e, m).unwrap(), want, "2^{e} mod {m}");
            // An exponent whose low 64 bits are zero is the case truncation
            // would silently turn into 2^0 == 1.
            if e & ((1i128 << 64) - 1) == 0 {
                assert_ne!(mod_pow(2, e, m).unwrap(), 1, "2^{e} collapsed to 1");
            }
        }
    }

    #[test]
    fn power_refuses_a_non_positive_modulus() {
        let invalid = "Invalid Modulus: Modulus must be positive";
        assert_message(mod_pow(2, 3, 0), invalid);
        assert_message(mod_pow(2, 3, -7), invalid);
    }

    #[test]
    fn power_inverts_the_base_for_a_negative_exponent() {
        assert_eq!(mod_pow(2, -1, 7).unwrap(), 4);
        // 3^-1 is 5 mod 7, so 3^-2 is 25 mod 7, which is 4.
        assert_eq!(mod_pow(3, -2, 7).unwrap(), 4);
        // A negative exponent of a non-unit is an error, not a guess.
        assert!(mod_pow(2, -1, 6).is_err());
    }

    #[test]
    fn power_agrees_with_exact_arithmetic() {
        for n in [2i128, 3, 7, 97, 1_000_000_007, (1 << 62) + 1] {
            for a in [-20i128, -1, 0, 1, 20] {
                for e in [0i128, 1, 2, 3, 17] {
                    let want = floor_rem(&BigInt::from(a), n)
                        .modpow(&BigInt::from(e), &BigInt::from(n))
                        .to_string()
                        .parse::<i128>()
                        .unwrap();
                    assert_eq!(mod_pow(a, e, n).unwrap(), want, "{a}^{e} mod {n}");
                }
            }
        }
    }

    #[test]
    fn power_is_exact_above_sixty_four_bits() {
        // The exponentiation loop multiplies through mod_mul, so this is where a
        // modulus past 2^63.5 would show up first.
        let m: i128 = 18_446_744_073_709_551_617;
        assert_eq!(
            mod_pow(1_000_000_007, 1_000_000, m).unwrap(),
            18_070_626_694_062_595_144
        );
    }

    // ---------------------------------------------------------------------
    // Primality
    // ---------------------------------------------------------------------

    /// The kernel's own 12 witnesses, but exponentiated with exact `BigInt`
    /// arithmetic — an independent check, not a second copy of the same code.
    fn miller_rabin_reference(n: i128) -> bool {
        let bn = BigInt::from(n);
        let two = BigInt::from(2i32);
        if bn < BigInt::from(2i32) {
            return false;
        }
        if bn == two {
            return true;
        }
        if (&bn % &two) == BigInt::from(0i32) {
            return false;
        }
        let mut d = &bn - 1i32;
        let mut s = 0u32;
        while (&d % &two) == BigInt::from(0i32) {
            d /= 2i32;
            s += 1;
        }
        let n_minus_1 = &bn - 1i32;
        for w in [2i32, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37] {
            let bw = BigInt::from(w);
            if bw >= bn {
                break;
            }
            let mut x = bw.modpow(&d, &bn);
            if x == BigInt::from(1i32) || x == n_minus_1 {
                continue;
            }
            let mut passed = false;
            for _ in 1..s {
                x = x.modpow(&two, &bn);
                if x == n_minus_1 {
                    passed = true;
                    break;
                }
            }
            if !passed {
                return false;
            }
        }
        true
    }

    #[test]
    fn primality_agrees_with_an_exact_miller_rabin() {
        let mut cases: Vec<i128> = (0i128..2_000).collect();
        cases.extend([
            1_000_000_007,
            2_147_483_647,
            1_000_000_000_039,
            2_305_843_009_213_693_951,
            2_305_843_009_213_693_948, // a second Mersenne prime's neighbour
            1_709_411_834_604_692_317_316_873_037_158_841_057, // 2^127 - 1
            1_709_411_834_604_692_317_316_873_037_158_841_055, // divisible by 5
            i128::MAX,
            i128::MAX - 2,
        ]);
        for n in cases {
            assert_eq!(is_prime(n), miller_rabin_reference(n), "is_prime({n})");
        }
    }

    #[test]
    fn primality_recognises_the_known_mersenne_primes() {
        // 2^127 - 1. Miller-Rabin exponentiates through powm, so this covers
        // the primality gate at the top of the i128 range.
        assert!(is_prime(170141183460469231731687303715884105727));
        assert!(is_prime(2_305_843_009_213_693_951));
        assert!(!is_prime(170141183460469231731687303715884105725));
    }

    #[test]
    fn primality_rejects_the_obvious_non_primes() {
        for n in [
            -1i128,
            0,
            1,
            4,
            9,
            100,
            561, // Carmichael
            1_709_411_834_604_692_317_316_873_037_158_841_055,
        ] {
            assert!(!is_prime(n), "is_prime({n})");
        }
    }

    // ---------------------------------------------------------------------
    // Quadratic symbols
    // ---------------------------------------------------------------------

    /// `(a / p)` by Euler's criterion, over exact `BigInt` arithmetic.
    fn legendre_reference(a: i128, p: i128) -> i8 {
        let bn = BigInt::from(p);
        let ar = floor_rem(&BigInt::from(a), p);
        if ar == BigInt::from(0i32) {
            return 0;
        }
        let l = ar.modpow(&((&bn - 1i32) / 2i32), &bn);
        if l == BigInt::from(1i32) {
            1
        } else if l == &bn - 1i32 {
            -1
        } else {
            0
        }
    }

    #[test]
    fn legendre_matches_eulers_criterion() {
        for p in [
            3i128,
            5,
            7,
            11,
            13,
            97,
            1_000_000_007,
            2_147_483_647,
            2_305_843_009_213_693_951,
        ] {
            for a in -200i128..200 {
                assert_eq!(
                    legendre_symbol(a, p).unwrap(),
                    legendre_reference(a, p),
                    "legendre({a}|{p})"
                );
            }
        }
    }

    #[test]
    fn legendre_requires_an_odd_prime() {
        for p in [0i128, 2, 9, 15, -7] {
            assert!(
                legendre_symbol(3, p).is_err(),
                "legendre(3|{p}) should refuse"
            );
        }
    }

    /// `(a / n)` as the product of the Legendre symbols over the odd prime
    /// factors of `n`, each raised to its exponent — the definition itself.
    fn jacobi_reference(a: i128, n: i128) -> i8 {
        let ar = exact_rem(&BigInt::from(a), n);
        if ar == 0 || gcd(ar, n) != 1 {
            // A value sharing a factor with the modulus is never a symbol of
            // +1 or -1; the product of the prime contributions collapses to 0.
            return 0;
        }
        let mut rest = n;
        let mut product: i8 = 1;
        let mut f = 3i128;
        while f * f <= rest {
            let mut e = 0u32;
            while rest % f == 0 {
                rest /= f;
                e += 1;
            }
            if e % 2 == 1 {
                let bf = BigInt::from(f);
                product *=
                    if BigInt::from(ar).modpow(&((&bf - 1i32) / 2i32), &bf) == BigInt::from(1i32) {
                        1
                    } else {
                        -1
                    };
            }
            f += 2;
        }
        if rest > 1 {
            let br = BigInt::from(rest);
            product *= if BigInt::from(ar).modpow(&((&br - 1i32) / 2i32), &br) == BigInt::from(1i32)
            {
                1
            } else {
                -1
            };
        }
        product
    }

    #[test]
    fn jacobi_matches_the_definition() {
        for n in [3i128, 5, 7, 9, 15, 21, 25, 45, 105, 1_000_000_007] {
            for a in -60i128..60 {
                assert_eq!(
                    jacobi_symbol(a, n).unwrap(),
                    jacobi_reference(a, n),
                    "jacobi({a}|{n})"
                );
            }
        }
    }

    #[test]
    fn jacobi_requires_an_odd_positive_modulus() {
        for n in [0i128, -15, 14, 2, -1] {
            assert!(jacobi_symbol(2, n).is_err(), "jacobi(2|{n}) should refuse");
        }
    }

    #[test]
    fn jacobi_is_one_for_a_one_modulus_and_agrees_with_legendre_on_primes() {
        assert_eq!(jacobi_symbol(0, 1).unwrap(), 1);
        assert_eq!(jacobi_symbol(1, 1).unwrap(), 1);
        assert_eq!(jacobi_symbol(0, 3).unwrap(), 0);
        assert_eq!(jacobi_symbol(1, 7).unwrap(), 1);
        for p in [3i128, 5, 7, 11, 13, 1_000_000_007] {
            for a in 0..p.min(50) {
                assert_eq!(jacobi_symbol(a, p).unwrap(), legendre_symbol(a, p).unwrap());
            }
        }
    }

    // ---------------------------------------------------------------------
    // Cross-checks against identities
    // ---------------------------------------------------------------------

    #[test]
    fn reducing_the_operands_does_not_change_the_result() {
        let mut rng = Rng(0x243F6A8885A308D3);
        for _ in 0..20_000 {
            let n = rng.modulus(80);
            let a = rng.next() as i128;
            let b = rng.next() as i128;
            let ra = mod_reduce(a, n);
            let rb = mod_reduce(b, n);
            assert_eq!(mod_add(a, b, n), mod_add(ra, rb, n));
            assert_eq!(mod_sub(a, b, n), mod_sub(ra, rb, n));
            assert_eq!(mod_mul(a, b, n), mod_mul(ra, rb, n));
        }
    }

    #[test]
    fn powers_compose() {
        // a^(x+y) == a^x * a^y (mod n)
        let mut rng = Rng(0x13198A2E03707344);
        for _ in 0..20_000 {
            let n = rng.modulus(64);
            let a = mod_reduce(rng.next() as i128, n);
            let x = (rng.next() % 24) as i128;
            let y = (rng.next() % 24) as i128;
            let lhs = mod_pow(a, x + y, n).unwrap();
            let rhs = mod_mul(mod_pow(a, x, n).unwrap(), mod_pow(a, y, n).unwrap(), n);
            assert_eq!(lhs, rhs, "a={a} x={x} y={y} n={n}");
        }
    }

    #[test]
    fn squaring_is_multiplication_by_itself() {
        let mut rng = Rng(0xA4093822299F31D0);
        for _ in 0..20_000 {
            let n = rng.modulus(96);
            let a = mod_reduce(rng.next() as i128, n);
            assert_eq!(mod_mul(a, a, n), mod_pow(a, 2, n).unwrap());
        }
    }

    #[test]
    fn a_negative_exponent_is_the_reciprocal_of_a_positive_one() {
        let mut rng = Rng(0x082EFA98EC4E6C89);
        let mut checked = 0;
        for _ in 0..5_000 {
            let n = rng.modulus(32) | 1;
            let a = mod_reduce(rng.next() as i128, n) | 1;
            if let Ok(inv) = mod_inv(a, n) {
                assert_eq!(mod_pow(a, -1, n).unwrap(), inv);
                checked += 1;
            }
        }
        assert!(checked > 1_000, "only {checked} invertible pairs exercised");
    }

    #[test]
    fn an_inverse_paired_with_its_value_is_the_identity() {
        // a * inv(a) == 1 (mod n) whenever gcd(a, n) == 1.
        let mut rng = Rng(0x452821E638D01377);
        let mut checked = 0;
        for _ in 0..50_000 {
            let n = rng.modulus(64);
            let a = mod_reduce(rng.next() as i128, n);
            if gcd(a, n) != 1 {
                continue;
            }
            assert_eq!(mod_mul(a, mod_inv(a, n).unwrap(), n), 1 % n, "a={a} n={n}");
            checked += 1;
        }
        assert!(
            checked > 10_000,
            "only {checked} invertible pairs exercised"
        );
    }

    // ---------------------------------------------------------------------
    // The randomised differential against exact arithmetic
    // ---------------------------------------------------------------------

    #[test]
    fn randomised_against_exact_arithmetic() {
        let mut rng = Rng(0x6A09E667F3BCC909);
        for round in 0..100_000u32 {
            let n = rng.modulus(1 + (round % 127));
            let a = rng.next() as i128;
            let b = rng.next() as i128;
            let bn = BigInt::from(n);
            let ra = floor_rem(&BigInt::from(a), n);
            let rb = floor_rem(&BigInt::from(b), n);

            assert_eq!(
                mod_reduce(a, n),
                ra.to_string().parse::<i128>().unwrap(),
                "reduce {round}"
            );
            assert_eq!(
                mod_add(a, b, n),
                exact_rem_wide(&(&ra + &rb), n),
                "add {round}"
            );
            assert_eq!(
                mod_sub(a, b, n),
                exact_rem_wide(&(&ra - &rb), n),
                "sub {round}"
            );
            assert_eq!(
                mod_mul(a, b, n),
                exact_rem_wide(&(&ra * &rb), n),
                "mul {round}"
            );
            assert_eq!(
                mod_neg(a, n),
                exact_rem_wide(&(&bn - &ra), n),
                "neg {round}"
            );

            let e = (rng.next() % 40) as i128;
            let want = ra
                .modpow(&BigInt::from(e), &bn)
                .to_string()
                .parse::<i128>()
                .unwrap();
            assert_eq!(mod_pow(a, e, n).unwrap(), want, "pow {round}");

            match mod_inv(a, n) {
                Ok(inv) => assert_eq!(
                    mod_mul(ra.to_string().parse().unwrap(), inv, n),
                    1 % n,
                    "inv {round}"
                ),
                // Refusing is only ever correct when the value is not a unit.
                Err(_) => assert!(
                    ra == BigInt::from(0i32)
                        || n == 1
                        || gcd(ra.to_string().parse().unwrap(), n) != 1,
                    "inv {round} wrongly refused"
                ),
            }
        }
    }

    // ---------------------------------------------------------------------
    // The zero-modulus contract, pinned as a whole
    // ---------------------------------------------------------------------

    #[test]
    fn the_zero_modulus_contract_is_unchanged() {
        // The ring helpers pass the operands through; the fallible ones report.
        // A caller that wants a real complaint about `mod 0` depends on getting
        // its own error rather than a panic — especially under the release
        // profile's `panic = "abort"`.
        assert_eq!(mod_reduce(5, 0), 5);
        assert_eq!(mod_add(5, 3, 0), 8);
        assert_eq!(mod_sub(5, 3, 0), 2);
        assert_eq!(mod_mul(5, 3, 0), 15);
        // Negation passes the negated operand through, so the sign is kept.
        assert_eq!(mod_neg(5, 0), -5);
        assert_eq!(mod_neg(0, 0), 0);
        // And the one branch that has to negate cannot itself overflow.
        assert_eq!(mod_neg(i128::MIN, 0), i128::MIN);
        assert_message(
            mod_pow(5, 3, 0),
            "Invalid Modulus: Modulus must be positive",
        );
        assert!(mod_inv(3, 0).is_err());
        assert!(mod_div(6, 3, 0).is_err());
    }
}
