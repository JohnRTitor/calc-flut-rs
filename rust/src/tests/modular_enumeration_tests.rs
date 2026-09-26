//! Tests for the enumerating and factoring half of `modular_arithmetic/`.
//!
//! These functions share a property the kernel tests do not have: they walk a
//! range whose length is the modulus, so their cost is set by something the user
//! types. The bound they report is part of their contract, and it is tested here
//! rather than assumed.

#[cfg(test)]
mod tests {
    use crate::modular_arithmetic::{
        error::ModError,
        mod_arith::is_prime,
        number_theory_ext::{
            MAX_LISTED, MAX_SCAN, MAX_TRIAL_DIVISOR, additive_inverse, element_order,
            euler_totient, has_primitive_roots, is_primitive_root, prime_factorization,
            primitive_roots, solve_linear_congruence, unit_group,
        },
        quadratic::quadratic_residues,
        ring_analysis::ring_classify,
    };
    use std::time::{Duration, Instant};

    /// 2^127 - 1, a Mersenne prime and the largest value `is_prime` is asked
    /// about anywhere in the app.
    const BIG_PRIME: i128 = 170_141_183_460_469_231_731_687_303_715_884_105_727;
    /// 2^61 - 1, a Mersenne prime. Trial division to its square root takes 2.2 s.
    const MID_PRIME: i128 = 2_305_843_009_213_693_951;
    /// A prime just above the trial-division bound, so that
    /// `MID_PRIME * JUST_OVER` has no factor the loop can reach.
    const JUST_OVER: i128 = 10_000_019;

    /// A semiprime with no factor at or below `MAX_TRIAL_DIVISOR`.
    const HARD_SEMIPRIME: i128 = MID_PRIME * JUST_OVER;

    // Checked here rather than at run time: both sides are constants, and this
    // is the property the refusal below depends on — trial division cannot reach
    // either factor, so the remainder it is left holding is still composite.
    const _: () = assert!(HARD_SEMIPRIME > MAX_TRIAL_DIVISOR * MAX_TRIAL_DIVISOR);

    /// Asserts on the rendered error rather than the error value, so these tests
    /// do not need `PartialEq` derived on a public error type for testing's sake.
    #[track_caller]
    fn assert_ok<T: std::fmt::Debug + PartialEq>(res: Result<T, ModError>, want: T) {
        match res {
            Ok(got) => assert_eq!(got, want),
            Err(e) => panic!("expected {want:?}, got error: {e}"),
        }
    }

    /// Independent totient: count the integers in `[1, n]` that are coprime to
    /// `n`. Definition rather than an algorithm, so it cannot share a bug with
    /// the factorisation the implementation is built on. The range is inclusive
    /// because that is what makes φ(1) and φ(2) both come out as 1.
    fn totient_by_counting(n: i128) -> i128 {
        (1..=n).filter(|k| gcd(*k, n) == 1).count() as i128
    }

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

    // ---------------------------------------------------------------------
    // prime_factorization
    // ---------------------------------------------------------------------

    #[test]
    fn factorisation_is_complete_for_everything_it_accepts() {
        // Whatever comes back must multiply back to the input, be made of primes
        // in ascending order, and agree with a naive count of each exponent.
        // From 2: 0 and 1 have no prime factors, and the empty product is 1.
        for n in 2i128..3_000 {
            let Ok(factors) = prime_factorization(n) else {
                continue;
            };
            let product: i128 = factors.iter().map(|(p, e)| p.pow(*e)).product::<i128>();
            assert_eq!(
                product,
                n.unsigned_abs() as i128,
                "factors of {n} rebuild wrong"
            );

            for w in factors.windows(2) {
                assert!(
                    w[0].0 < w[1].0,
                    "factors of {n} are not ascending: {factors:?}"
                );
            }
            for &(p, e) in &factors {
                assert!(
                    is_prime(p),
                    "{p} is not prime, so it is not a factor of {n}"
                );
                let mut left = n.unsigned_abs() as i128;
                let mut seen = 0;
                while left % p == 0 {
                    left /= p;
                    seen += 1;
                }
                assert_eq!(seen, e as i128, "exponent of {p} in {n} is {seen}, not {e}");
                assert_eq!(left, product / p.pow(e), "leftover after {p} in {n}");
            }
        }
    }

    #[test]
    fn factorisation_handles_the_degenerate_inputs() {
        assert_ok(prime_factorization(0), vec![]);
        assert_ok(prime_factorization(1), vec![]);
        assert_ok(prime_factorization(-1), vec![]);
        assert_ok(prime_factorization(2), vec![(2, 1)]);
        assert_ok(prime_factorization(-2), vec![(2, 1)]);
        assert_ok(prime_factorization(12), vec![(2, 2), (3, 1)]);
        assert_ok(prime_factorization(360), vec![(2, 3), (3, 2), (5, 1)]);
    }

    #[test]
    fn a_large_prime_is_recognised_without_walking_to_its_square_root() {
        // Before the primality short-circuit this was the worst case: 6.5e18
        // iterations for the 2^127 prime and 2.2 s for the 2^61 one.
        for p in [MID_PRIME, BIG_PRIME] {
            let started = Instant::now();
            let elapsed = started.elapsed();
            assert_ok(prime_factorization(p), vec![(p, 1)]);
            assert!(
                elapsed < Duration::from_millis(100),
                "prime_factorization({p}) took {elapsed:?}; the short-circuit is not firing"
            );
        }
    }

    #[test]
    fn a_large_prime_times_a_small_factor_is_also_quick() {
        // 3 * 5 * (2^61 - 1): the remainder turns prime as soon as 3 and 5 come
        // out, so the loop must not walk the rest of the bound looking for more.
        let n = 15 * MID_PRIME;
        let started = Instant::now();
        assert_ok(prime_factorization(n), vec![(3, 1), (5, 1), (MID_PRIME, 1)]);
        let elapsed = started.elapsed();
        assert!(
            elapsed < Duration::from_millis(100),
            "prime_factorization({n}) took {elapsed:?}"
        );
    }

    #[test]
    fn a_value_it_cannot_factor_is_refused_rather_than_truncated() {
        // Both factors sit above the bound, so trial division finds nothing and
        // the remainder is still composite. A partial answer here would silently
        // corrupt phi, element order and the nilpotent count, all of which are
        // computed from the complete list.
        match prime_factorization(HARD_SEMIPRIME) {
            Err(ModError::TooLarge(message)) => {
                assert!(
                    message.contains(&MAX_TRIAL_DIVISOR.to_string()),
                    "the error should name the bound it hit: {message}"
                );
            }
            other => panic!("expected a TooLarge refusal, got {other:?}"),
        }
    }

    #[test]
    fn a_value_with_no_representable_magnitude_is_refused() {
        assert!(prime_factorization(i128::MIN).is_err());
        assert!(euler_totient(i128::MIN).is_err());
    }

    // ---------------------------------------------------------------------
    // euler_totient
    // ---------------------------------------------------------------------

    #[test]
    fn totient_counts_what_the_definition_says() {
        for n in 1i128..600 {
            match euler_totient(n) {
                Ok(got) => assert_eq!(got, totient_by_counting(n), "phi({n})"),
                Err(e) => panic!("phi({n}) errored: {e}"),
            }
        }
        assert_ok(euler_totient(0), 0);
        assert_ok(euler_totient(-12), 4);
    }

    #[test]
    fn totient_of_a_prime_is_one_less_than_the_prime() {
        for p in [3i128, 97, 1_000_000_007, MID_PRIME, BIG_PRIME] {
            assert_ok(euler_totient(p), p - 1);
        }
    }

    #[test]
    fn totient_refuses_rather_than_guessing() {
        assert!(euler_totient(HARD_SEMIPRIME).is_err());
    }

    // ---------------------------------------------------------------------
    // Order, primitive roots, congruences
    // ---------------------------------------------------------------------

    #[test]
    fn element_order_and_primitive_roots_still_resolve() {
        assert_ok(element_order(2, 7), 3);
        assert_ok(element_order(3, 7), 6);
        assert_ok(element_order(1, 7), 1);
        assert_eq!(primitive_roots(7).unwrap(), vec![3, 5]);
        assert_ok(has_primitive_roots(7), true);
        assert_ok(has_primitive_roots(12), false);
        assert!(is_primitive_root(3, 7).unwrap());
        assert!(!is_primitive_root(2, 7).unwrap());
        assert_eq!(additive_inverse(3, 7), 4);
    }

    #[test]
    fn linear_congruences_still_resolve() {
        assert_ok(solve_linear_congruence(2, 4, 6), vec![2, 5]);
        assert_ok(solve_linear_congruence(3, 1, 7), vec![5]);
        assert!(solve_linear_congruence(2, 1, 4).is_err());
    }

    #[test]
    fn order_refuses_a_non_unit() {
        assert!(element_order(2, 4).is_err());
        assert!(element_order(1, 1).is_err());
    }

    // ---------------------------------------------------------------------
    // ring_classify
    // ---------------------------------------------------------------------

    #[test]
    fn ring_classification_reports_what_it_used_to() {
        let ring = ring_classify(12).unwrap();
        assert_eq!(ring.n, 12);
        assert!(!ring.is_field);
        assert!(!ring.is_integral_domain);
        assert_eq!(ring.units, vec![1, 5, 7, 11]);
        assert_eq!(ring.zero_divisors, vec![2, 3, 4, 6, 8, 9, 10]);
        assert_eq!(ring.idempotents, vec![0, 1, 4, 9]);
        assert_eq!(ring.nilpotents, vec![0, 6]);

        let field = ring_classify(7).unwrap();
        assert!(field.is_field);
        assert!(field.is_integral_domain);
        assert_eq!(field.units_count, 6);
    }

    #[test]
    fn ring_classification_of_a_large_prime_is_quick_and_honest() {
        // ring_classify factorises n and enumerates its units, idempotents,
        // zero divisors and nilpotents, so it inherits both costs. On the 2^127
        // prime the factorisation is now a short circuit, and every list stops at
        // MAX_SCAN — which is what the old code could not say, because a prime has
        // no zero divisors, two idempotents and one nilpotent, so none of the
        // three ever reached its own limit and each walked all 2^127 elements.
        let started = Instant::now();
        let field = ring_classify(BIG_PRIME);
        let elapsed = started.elapsed();

        let field = field.unwrap();
        assert!(field.is_field);
        assert!(field.is_integral_domain);
        // The counts are arithmetic, so they stay exact past the scan ceiling.
        assert_eq!(field.units_count, BIG_PRIME - 1);
        assert_eq!(field.zero_divisors_count, 0);
        assert_eq!(field.idempotents_count, 2);
        assert_eq!(field.nilpotents_count, 1);
        // The lists are not, and the caller is told so rather than handed a
        // partial set that still claims to be Z_n.
        assert!(field.is_truncated);
        assert!(field.units.len() as i128 <= MAX_SCAN);
        assert!(field.zero_divisors.is_empty());
        assert!(field.idempotents.len() <= 2);
        assert!(
            elapsed < Duration::from_secs(2),
            "ring_classify(2^127-1) took {elapsed:?}"
        );
    }

    #[test]
    fn ring_classification_is_untruncated_below_the_scan_ceiling() {
        for n in [2i128, 7, 12, 100, 360, 999] {
            assert!(!ring_classify(n).unwrap().is_truncated, "Z_{n}");
        }
    }

    #[test]
    fn ring_classification_reports_an_unfactorable_modulus() {
        assert!(ring_classify(HARD_SEMIPRIME).is_err());
    }

    // ---------------------------------------------------------------------
    // Whole lists are refused rather than truncated
    // ---------------------------------------------------------------------

    #[test]
    fn listing_a_group_or_residues_past_the_limit_is_refused() {
        // Both are rendered as one comma-joined string across FFI, so there is no
        // partial answer worth giving.
        assert!(unit_group(MAX_LISTED + 1).is_err());
        assert!(quadratic_residues(MAX_LISTED + 1).is_err());
        assert!(unit_group(BIG_PRIME).is_err());
        assert!(quadratic_residues(BIG_PRIME).is_err());
        assert!(unit_group(i128::MIN).is_err());
        assert!(quadratic_residues(i128::MIN).is_err());
    }

    #[test]
    fn listing_still_works_up_to_the_limit() {
        assert_ok(unit_group(12), vec![1, 5, 7, 11]);
        assert_ok(unit_group(-12), vec![1, 5, 7, 11]);
        assert_ok(unit_group(1), vec![]);
        assert_ok(quadratic_residues(7), vec![0, 1, 2, 4]);
        assert_ok(quadratic_residues(1), vec![]);
        // The limit itself is still answered, not refused.
        assert!(unit_group(MAX_LISTED).is_ok());
    }
}
