//! Tests for the number theory subsystem.
//!
//! The cases that matter most are the ones where a plausible-looking answer
//! would be wrong: the sign of a negative number's factorisation, and the
//! several quantities that are undefined for 0 and 1.

#[cfg(test)]
mod tests {
    use crate::symbolic::error::{SymbolicError, SymbolicErrorKind};
    use crate::symbolic::ntheory::{MAX_DIGITS, analyse, coprime, gcd, lcm};

    /// The factorisation rendered the way the UI shows it.
    fn factors_of(n: &str) -> String {
        let analysis = analyse(n).expect("should analyse");
        analysis
            .factors
            .iter()
            .map(|factor| {
                if factor.power == 1 {
                    factor.prime.clone()
                } else {
                    format!("{}^{}", factor.prime, factor.power)
                }
            })
            .collect::<Vec<String>>()
            .join(" * ")
    }

    // ---------- factorisation ----------

    #[test]
    fn test_factorisation_of_a_composite() {
        assert_eq!(factors_of("360"), "2^3 * 3^2 * 5");
        assert_eq!(factors_of("12"), "2^2 * 3");
    }

    #[test]
    fn test_factorisation_of_a_prime_is_itself() {
        assert_eq!(factors_of("97"), "97");
    }

    #[test]
    fn test_factorisation_of_one_is_empty() {
        assert_eq!(factors_of("1"), "");
    }

    #[test]
    fn test_factorisation_of_a_negative_keeps_its_sign() {
        // The backend factorises the magnitude and reports the sign nowhere, so
        // -12 as "2^2 * 3" would be a different number from -12.
        assert_eq!(factors_of("-12"), "-1 * 2^2 * 3");
        assert_eq!(factors_of("-97"), "-1 * 97");
        assert_eq!(factors_of("-1"), "-1");
    }

    #[test]
    fn test_factorisation_of_a_large_integer_is_exact() {
        // Bigger than any machine integer, so a float would have lost digits.
        assert_eq!(
            factors_of("123456789012345678901234567890"),
            "2 * 3^3 * 5 * 7 * 13 * 31 * 37 * 211 * 241 * 2161 * 3607 * 3803 * 2906161"
        );
    }

    // ---------- divisors ----------

    #[test]
    fn test_divisors_are_listed_in_order() {
        let analysis = analyse("12").unwrap();
        assert_eq!(analysis.divisors, vec!["1", "2", "3", "4", "6", "12"]);
        assert_eq!(analysis.divisor_count, 6);
    }

    #[test]
    fn test_divisor_sum_is_exact() {
        let analysis = analyse("12").unwrap();
        assert_eq!(analysis.divisor_sum, "28");
    }

    #[test]
    fn test_zero_has_no_finite_divisor_list() {
        // Every positive integer divides 0. Reporting a count would be wrong, so
        // it is reported as absent with a reason.
        let analysis = analyse("0").unwrap();
        assert!(analysis.divisors.is_empty());
        assert_eq!(analysis.divisor_count, 0);
        assert!(analysis.divisor_sum.is_empty());
        let details = analysis.details.expect("the absence must be explained");
        assert!(details.contains("infinitely many"), "got: {details}");
    }

    // ---------- primality and friends ----------

    #[test]
    fn test_primality() {
        assert!(analyse("97").unwrap().is_prime);
        assert!(!analyse("91").unwrap().is_prime, "91 = 7 * 13");
        assert!(!analyse("1").unwrap().is_prime, "1 is not prime");
        assert!(!analyse("0").unwrap().is_prime, "0 is not prime");
        assert!(!analyse("-7").unwrap().is_prime, "negatives are not prime");
    }

    #[test]
    fn test_squares() {
        assert!(analyse("49").unwrap().is_square);
        assert!(!analyse("50").unwrap().is_square);
        assert!(!analyse("-4").unwrap().is_square, "a negative is not a square");
    }

    #[test]
    fn test_perfect_numbers() {
        assert!(analyse("28").unwrap().is_perfect, "28 = 1+2+4+7+14");
        assert!(analyse("6").unwrap().is_perfect);
        assert!(!analyse("27").unwrap().is_perfect);
    }

    #[test]
    fn test_carmichael_numbers() {
        // The three smallest: 561, 1105, 1729.
        assert!(analyse("561").unwrap().is_carmichael);
        assert!(analyse("1105").unwrap().is_carmichael);
        assert!(analyse("1729").unwrap().is_carmichael);
        assert!(!analyse("562").unwrap().is_carmichael, "562 sits between 561 and 1105");
    }

    // ---------- totient ----------

    #[test]
    fn test_totient() {
        assert_eq!(analyse("36").unwrap().totient, "12");
        assert_eq!(analyse("1").unwrap().totient, "1", "phi(1) is 1");
        assert_eq!(analyse("13").unwrap().totient, "12", "a prime has phi p-1");
    }

    #[test]
    fn test_totient_of_zero_is_undefined() {
        // There is no count to give, so it is reported as absent with a reason
        // rather than as 0, which would be a real totient.
        let analysis = analyse("0").unwrap();
        assert!(analysis.totient.is_empty());
        let details = analysis.details.expect("the absence must be explained");
        assert!(details.contains("totient"), "got: {details}");
    }

    // ---------- prime neighbours ----------

    #[test]
    fn test_prime_neighbours() {
        let analysis = analyse("90").unwrap();
        assert_eq!(analysis.next_prime, "97");
        assert_eq!(analysis.previous_prime, "89");
    }

    #[test]
    fn test_no_smaller_prime_below_two() {
        let analysis = analyse("2").unwrap();
        assert!(analysis.previous_prime.is_empty());
        assert!(
            analysis
                .details
                .as_deref()
                .is_some_and(|d| d.contains("smaller prime")),
            "the absence must be explained"
        );
    }

    #[test]
    fn test_prime_neighbours_of_a_negative_use_the_magnitude() {
        let analysis = analyse("-10").unwrap();
        assert_eq!(analysis.next_prime, "11");
        let details = analysis.details.expect("the convention must be stated");
        assert!(details.contains("magnitude"), "got: {details}");
    }

    // ---------- two-number operations ----------

    #[test]
    fn test_gcd_and_lcm() {
        assert_eq!(gcd("48", "18").unwrap(), "6");
        assert_eq!(lcm("4", "6").unwrap(), "12");
    }

    #[test]
    fn test_gcd_and_lcm_of_zero() {
        // gcd(0, n) is n and lcm(0, n) is 0, both conventionally non-negative.
        assert_eq!(gcd("0", "7").unwrap(), "7");
        assert_eq!(lcm("0", "7").unwrap(), "0");
    }

    #[test]
    fn test_gcd_and_lcm_are_never_negative() {
        // The magnitude is taken, so gcd(-4, 6) is 2 rather than -2.
        assert_eq!(gcd("-4", "6").unwrap(), "2");
        assert_eq!(lcm("-4", "6").unwrap(), "12");
    }

    #[test]
    fn test_gcd_of_large_integers_is_exact() {
        assert_eq!(
            gcd("123456789012345678901234567890", "987654321098765432109876543210")
                .unwrap(),
            "9000000000900000000090"
        );
    }

    #[test]
    fn test_coprime() {
        assert!(coprime("8", "15").unwrap());
        assert!(!coprime("8", "12").unwrap());
    }

    // ---------- input errors ----------

    #[test]
    fn test_an_empty_number_is_refused() {
        let error = analyse("   ").unwrap_err();
        assert!(matches!(error, SymbolicError::EmptyNumber));
        assert_eq!(error.kind(), SymbolicErrorKind::Input);
    }

    #[test]
    fn test_a_non_integer_is_refused_rather_than_truncated() {
        // Rounding 2.5 to 2 would answer a different question, and there is no
        // meaningful "prime near" a non-integer.
        for input in ["2.5", "abc", "1e5", "12 34", "--3", "4x"] {
            let error = analyse(input).unwrap_err();
            assert!(
                matches!(error, SymbolicError::NotAnInteger { .. }),
                "{input:?} should be refused, got {error:?}"
            );
            assert_eq!(error.kind(), SymbolicErrorKind::Input);
        }
    }

    #[test]
    fn test_a_bare_minus_is_refused() {
        assert!(analyse("-").is_err());
        assert!(analyse("+").is_err());
    }

    #[test]
    fn test_a_leading_plus_is_accepted() {
        assert_eq!(factors_of("+12"), "2^2 * 3");
    }

    #[test]
    fn test_oversized_numbers_are_refused() {
        let huge = "9".repeat(MAX_DIGITS + 1);
        let error = analyse(&huge).unwrap_err();
        assert!(matches!(error, SymbolicError::TooLarge(_)));
        assert_eq!(error.kind(), SymbolicErrorKind::TooLarge);
    }

    #[test]
    fn test_a_number_at_the_cap_is_accepted() {
        // The cap bounds input size, not the work, so this asserts acceptance
        // and nothing more. A number of the same length can still be slow
        // depending on its factors, which is why the help text says the cap is
        // not a performance guarantee.
        let at_cap = "9".repeat(MAX_DIGITS);
        assert!(analyse(&at_cap).is_ok());
    }

    #[test]
    fn test_a_large_but_ordinary_number_analyses_quickly() {
        // The cap exists so ordinary input is instant. This holds it to that:
        // a 20-digit semiprime must not be something the user waits on.
        let start = std::time::Instant::now();
        let number = "104729104723";
        let analysis = analyse(number).expect("should analyse");
        assert!(start.elapsed() < std::time::Duration::from_secs(1));

        // The invariant, not a product worked out by hand: whatever comes back
        // must rebuild the number exactly.
        let rebuilt: i128 = analysis
            .factors
            .iter()
            .map(|factor| {
                let prime: i128 = factor.prime.parse().unwrap();
                prime.pow(factor.power)
            })
            .product();
        assert_eq!(rebuilt, number.parse::<i128>().unwrap());
    }

    #[test]
    fn test_no_number_error_leaks_backend_terminology() {
        for input in ["2.5", "", "abc"] {
            let message = analyse(input).unwrap_err().to_string();
            for leaked in ["symplex", "BigInt", "parse", "None", "ParseError"] {
                assert!(
                    !message.contains(leaked),
                    "leaked '{leaked}': {message}"
                );
            }
        }
    }
}



