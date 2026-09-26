//! Tests for equation solving.
//!
//! The four solution kinds are the point of this file: a unique answer, a finite
//! set, an identity, and an impossibility are four different mathematical facts,
//! and none of them is a failure. They are asserted as first-class cases
//! because conflating any of them is the easy mistake to make.

#[cfg(test)]
mod tests {
    use crate::symbolic::error::{SymbolicError, SymbolicErrorKind};
    use crate::symbolic::solve::{SolutionCategory, solve};

    fn solved(equation: &str) -> (SolutionCategory, Vec<String>) {
        let outcome = solve(equation, Some("x"), false).expect("should solve");
        (outcome.kind, outcome.solutions)
    }

    // ---------- unique ----------

    #[test]
    fn test_linear_equation_has_one_solution() {
        let (kind, solutions) = solved("2x = 4");
        assert_eq!(kind, SolutionCategory::Unique);
        assert_eq!(solutions, vec!["2"]);
    }

    #[test]
    fn test_unique_solution_keeps_its_exact_form() {
        // Must not decay to a decimal.
        let (_, solutions) = solved("3x = 1");
        assert_eq!(solutions, vec!["1/3"]);
    }

    #[test]
    fn test_trigonometric_solution_is_exact() {
        let (kind, solutions) = solved("sin(x) = 1");
        assert_eq!(kind, SolutionCategory::Unique);
        assert_eq!(solutions, vec!["1/2*pi"]);
    }

    // ---------- multiple ----------

    #[test]
    fn test_quadratic_reports_every_real_root() {
        let (kind, solutions) = solved("x^2 = 4");
        assert_eq!(kind, SolutionCategory::Multiple);
        assert_eq!(solutions, vec!["2", "-2"]);
    }

    #[test]
    fn test_irrational_roots_are_kept_symbolic() {
        let (kind, solutions) = solved("x^2 = 2");
        assert_eq!(kind, SolutionCategory::Multiple);
        assert_eq!(solutions, vec!["sqrt(2)", "-sqrt(2)"]);
    }

    #[test]
    fn test_complex_roots_are_reported_rather_than_discarded() {
        // The app presents complex results, so a negative discriminant yields
        // the complex roots instead of a bare "no solution".
        let (kind, solutions) = solved("x^2 = -1");
        assert_eq!(kind, SolutionCategory::Multiple);
        assert_eq!(solutions, vec!["I", "-I"]);
    }

    #[test]
    fn test_mixed_real_and_complex_roots_are_all_kept() {
        let (kind, solutions) = solved("x^4 = 16");
        assert_eq!(kind, SolutionCategory::Multiple);
        assert_eq!(solutions.len(), 4);
        assert!(solutions.contains(&"2".to_string()));
        assert!(solutions.contains(&"-2".to_string()));
    }

    #[test]
    fn test_repeated_root_still_counts_as_one_solution() {
        // (x - 1)^2 = 0 has one distinct value, not two.
        let (kind, solutions) = solved("(x - 1)^2 = 0");
        assert_eq!(kind, SolutionCategory::Unique);
        assert_eq!(solutions, vec!["1"]);
    }

    // ---------- infinite ----------

    #[test]
    fn test_identity_is_reported_as_infinite() {
        // An identity is a real answer, not an error and not an empty list.
        for equation in ["x = x", "0 = 0", "x/x = 1", "x + 1 = x + 1"] {
            let (kind, solutions) = solved(equation);
            assert_eq!(
                kind,
                SolutionCategory::Infinite,
                "{equation} should be an identity"
            );
            assert!(
                solutions.is_empty(),
                "{equation} should not list finitely many solutions"
            );
        }
    }

    #[test]
    fn test_infinite_solutions_need_no_qualifier() {
        // The UI states which of the four outcomes it is; a qualifier restating
        // that would print the same sentence twice.
        let outcome = solve("x = x", Some("x"), false).unwrap();
        assert_eq!(outcome.kind, SolutionCategory::Infinite);
        assert!(
            outcome.details.is_none(),
            "the outcome is already stated by the UI"
        );
    }

    #[test]
    fn test_no_solution_needs_no_qualifier() {
        let outcome = solve("1 = 2", Some("x"), false).unwrap();
        assert_eq!(outcome.kind, SolutionCategory::None);
        assert!(outcome.details.is_none());
    }

    // ---------- none ----------

    #[test]
    fn test_contradiction_is_reported_as_no_solution() {
        for equation in ["1 = 2", "x + 1 = x"] {
            let (kind, solutions) = solved(equation);
            assert_eq!(
                kind,
                SolutionCategory::None,
                "{equation} cannot be satisfied"
            );
            assert!(solutions.is_empty());
        }
    }

    #[test]
    fn test_candidate_roots_that_fail_verification_are_discarded() {
        // The solver squares the equation to find a candidate, which admits
        // x = 1 — but sqrt(1) is 1, not -1. Reporting it would be a confident
        // wrong answer, so it is checked and thrown away, leaving the true
        // answer: no solution.
        let (kind, solutions) = solved("sqrt(x) = -1");
        assert_eq!(kind, SolutionCategory::None);
        assert!(solutions.is_empty());
    }

    #[test]
    fn test_discarded_candidates_are_reported_rather_than_hidden() {
        // Silently returning a shorter answer would look like the whole truth.
        let outcome = solve("sqrt(x) = -1", Some("x"), false).unwrap();
        let details = outcome.details.expect("discarding must be explained");
        assert!(
            details.contains("discarded"),
            "expected an explanation, got: {details}"
        );
    }

    #[test]
    fn test_no_qualifier_when_nothing_was_discarded() {
        let outcome = solve("x^2 = 4", Some("x"), false).unwrap();
        assert!(
            outcome.details.is_none(),
            "a clean solve should not carry a caveat"
        );
    }

    #[test]
    fn test_every_reported_solution_actually_satisfies_the_equation() {
        // The invariant behind the verification: whatever is reported, plugging it
        // back in gives exactly zero.
        let ctx = symplex::prelude::Context::new();
        let x = ctx.symbol("x");

        for equation in [
            "x^2 = 4", "2x = 4", "x^2 = 2", "x^3 = x", "x^4 = 16",
            "sin(x) = 1", "x^2 = -1", "(x - 1)^2 = 0", "sqrt(x) = -1",
        ] {
            let (lhs_src, rhs_src) = equation.split_once('=').unwrap();
            let lhs = ctx.parse(lhs_src).unwrap();
            let rhs = ctx.parse(rhs_src).unwrap();

            for solution in solve(equation, Some("x"), false).unwrap().solutions {
                let candidate = ctx.parse(&solution).unwrap();
                let residual = (&lhs.subs(&x, &candidate) - &rhs.subs(&x, &candidate)).simplify();
                assert!(
                    residual.is_zero_structural(),
                    "{solution} was reported for {equation} but leaves {residual}"
                );
            }
        }
    }

    // ---------- input errors ----------

    #[test]
    fn test_an_expression_is_not_an_equation() {
        let error = solve("x^2 + 1", Some("x"), false).unwrap_err();
        assert!(matches!(error, SymbolicError::NotEquation));
        assert_eq!(error.kind(), SymbolicErrorKind::Unsupported);
        assert!(
            error.suggestion().is_some(),
            "should suggest what an equation looks like"
        );
    }

    #[test]
    fn test_two_equals_signs_are_refused() {
        // Resolving this to just one of the two equations would answer a
        // different question than the one asked.
        let error = solve("x = y = 2", Some("x"), false).unwrap_err();
        assert!(matches!(error, SymbolicError::InvalidExpression(_)));
    }

    #[test]
    fn test_an_empty_side_is_refused() {
        for equation in ["= 4", "x = ", " = "] {
            assert!(
                solve(equation, Some("x"), false).is_err(),
                "{equation:?} should be refused"
            );
        }
    }

    #[test]
    fn test_solving_without_a_variable_is_refused() {
        let error = solve("x^2 = 4", None, false).unwrap_err();
        assert!(matches!(error, SymbolicError::NoVariable));
    }

    #[test]
    fn test_solving_for_an_absent_variable_yields_nothing() {
        // x^2 = 4 has no solution for y, which is not an error: it is a
        // statement about y that is false.
        let (kind, solutions) = {
            let outcome = solve("x^2 = 4", Some("y"), false).unwrap();
            (outcome.kind, outcome.solutions)
        };
        assert_eq!(kind, SolutionCategory::None);
        assert!(solutions.is_empty());
    }

    #[test]
    fn test_empty_and_oversized_input() {
        assert!(matches!(
            solve("   ", Some("x"), false).unwrap_err(),
            SymbolicError::EmptyExpression
        ));
        let huge = format!("{} = 0", "x".repeat(crate::symbolic::MAX_EXPRESSION_CHARS + 1));
        assert!(matches!(
            solve(&huge, Some("x"), false).unwrap_err(),
            SymbolicError::TooLarge(_)
        ));
    }

    // ---------- steps ----------

    #[test]
    fn test_steps_are_optional_and_name_the_equation() {
        let quiet = solve("x^2 = 4", Some("x"), false).unwrap();
        assert!(quiet.steps.is_none());

        let traced = solve("x^2 = 4", Some("x"), true).unwrap();
        let steps = traced.steps.expect("steps were requested");
        assert!(steps.contains("x^2 = 4"), "got: {steps}");
        assert!(steps.contains("x"), "should say what it solved for: {steps}");
    }

    // ---------- the guard that matters most ----------

    #[test]
    fn test_no_solve_error_ever_reaches_the_ui_as_a_failure() {
        // "No solution" and "infinitely many" must never be reported as errors,
        // or the UI would style a correct answer as a mistake.
        for equation in ["x = x", "1 = 2", "x + 1 = x", "0 = 0"] {
            assert!(
                solve(equation, Some("x"), false).is_ok(),
                "{equation} is an answer, not a failure"
            );
        }
    }

    #[test]
    fn test_no_solution_messages_leak_backend_terminology() {
        let cases = [
            solve("x^2 + 1", Some("x"), false),
            solve("x = y = 2", Some("x"), false),
            solve("= 4", Some("x"), false),
        ];
        for case in cases {
            let message = case.unwrap_err().to_string();
            for leaked in ["symplex", "Symplex", "SymplexError", "Ex<", "None"] {
                assert!(
                    !message.contains(leaked),
                    "leaked '{}': {}",
                    leaked,
                    message
                );
            }
        }
    }
}
