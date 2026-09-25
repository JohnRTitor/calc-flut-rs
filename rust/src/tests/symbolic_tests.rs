//! Tests for the symbolic (CAS) subsystem.
//!
//! Expectations are written against exact mathematical results, never
//! approximations: every operation here is exact `Ratio<BigInt>` arithmetic,
//! so a test that accepted a decimal would be hiding a precision bug.

#[cfg(test)]
mod tests {
    use crate::symbolic::error::{SymbolicError, SymbolicErrorKind};
    use crate::symbolic::evaluator::{
        MAX_EXPRESSION_CHARS, SymbolicOperation, transform,
    };

    /// Runs `operation` against `expression`, supplying `x` as the acting
    /// variable so the operation is never blocked on variable discovery.
    fn run(expression: &str, operation: SymbolicOperation) -> Result<String, SymbolicError> {
        let needs_variable = matches!(operation, SymbolicOperation::Factor);
        transform(
            expression,
            operation,
            needs_variable.then_some("x"),
            false,
        )
        .map(|outcome| outcome.value)
    }

    // ---------- simplify ----------

    #[test]
    fn test_simplify_combines_like_terms() {
        assert_eq!(run("2x + 3x", SymbolicOperation::Simplify).unwrap(), "5*x");
        assert_eq!(run("x + x + x", SymbolicOperation::Simplify).unwrap(), "3*x");
    }

    #[test]
    fn test_simplify_reduces_identities() {
        assert_eq!(run("x - x", SymbolicOperation::Simplify).unwrap(), "0");
        assert_eq!(run("x * 1", SymbolicOperation::Simplify).unwrap(), "x");
        assert_eq!(run("0 * x", SymbolicOperation::Simplify).unwrap(), "0");
    }

    #[test]
    fn test_simplify_keeps_exact_rationals() {
        // Must not decay into a decimal: 1/3 stays an exact fraction.
        assert_eq!(
            run("1/3 + 1/6", SymbolicOperation::Simplify).unwrap(),
            "1/2"
        );
    }

    #[test]
    fn test_simplify_is_idempotent() {
        let once = run("(x+1)*(x-1)", SymbolicOperation::Simplify).unwrap();
        let twice = run(&once, SymbolicOperation::Simplify).unwrap();
        assert_eq!(once, twice, "simplifying an already-simple form changed it");
    }

    // ---------- expand ----------

    #[test]
    fn test_expand_multiplies_out() {
        assert_eq!(
            run("(x + 1)*(x + 1)", SymbolicOperation::Expand).unwrap(),
            "x^2 + 2*x + 1"
        );
        assert_eq!(
            run("(x + 1)*(x^2 + 1)", SymbolicOperation::Expand).unwrap(),
            "x^3 + x^2 + x + 1"
        );
    }

    #[test]
    fn test_expand_distributes_over_subtraction() {
        assert_eq!(
            run("(x - 1)*(x + 1)", SymbolicOperation::Expand).unwrap(),
            "x^2 - 1"
        );
    }

    // ---------- factor ----------

    #[test]
    fn test_factor_difference_of_squares() {
        assert_eq!(
            run("x^2 - 4", SymbolicOperation::Factor).unwrap(),
            "(x - 2)*(x + 2)"
        );
    }

    #[test]
    fn test_factor_polynomial() {
        assert_eq!(
            run("x^2 + 3*x + 2", SymbolicOperation::Factor).unwrap(),
            "(x + 1)*(x + 2)"
        );
    }

    #[test]
    fn test_factor_leaves_irreducible_alone() {
        // x^2 + 1 has no real/integer factors; the expression must come back
        // unchanged rather than being mangled into something plausible.
        assert_eq!(run("x^2 + 1", SymbolicOperation::Factor).unwrap(), "x^2 + 1");
    }

    #[test]
    fn test_factor_reports_nothing_to_factor() {
        let outcome = transform("x^2 + 1", SymbolicOperation::Factor, Some("x"), false).unwrap();
        assert_eq!(
            outcome.details.as_deref(),
            Some("No further factors over the integers")
        );
    }

    #[test]
    fn test_factor_without_variable_is_refused() {
        // A constant has nothing to factor; refuse rather than invent a factor.
        let error = transform("6", SymbolicOperation::Factor, None, false).unwrap_err();
        assert!(matches!(error, SymbolicError::NoVariable));
        assert_eq!(error.kind(), SymbolicErrorKind::Unsupported);
    }

    // ---------- alternate forms ----------

    #[test]
    fn test_alternate_forms_exclude_the_chosen_operation() {
        let outcome = transform(
            "(x + 1)*(x + 1)",
            SymbolicOperation::Expand,
            Some("x"),
            false,
        )
        .unwrap();

        let labels: Vec<&str> = outcome
            .alternate_forms
            .iter()
            .map(|f| f.label.as_str())
            .collect();
        assert!(!labels.contains(&"Expanded"), "re-offered the chosen form");
        assert!(labels.contains(&"Simplified"));
        assert!(labels.contains(&"Factored"));
    }

    #[test]
    fn test_alternate_forms_are_mathematically_equal_to_the_primary() {
        // Every offered form must describe the same expression, not a
        // different one. Cross-check by re-expanding each form in one context.
        let ctx = symplex::prelude::Context::new();
        let expected = ctx.parse("x^2 - 1").unwrap().expand();

        let outcome =
            transform("(x + 1)*(x - 1)", SymbolicOperation::Simplify, Some("x"), false).unwrap();

        assert!(!outcome.alternate_forms.is_empty());
        for form in &outcome.alternate_forms {
            let reparsed = ctx.parse(&form.expression).unwrap();
            assert_eq!(
                reparsed.expand(),
                expected,
                "alternate form '{}' is not equivalent to the primary value",
                form.label
            );
        }
    }

    #[test]
    fn test_alternate_forms_omit_what_cannot_be_produced() {
        // With no variable chosen, factoring cannot run, so it must not appear
        // as a dead chip offering an answer that is not there.
        let outcome = transform("2x + 3x", SymbolicOperation::Simplify, None, false).unwrap();
        let labels: Vec<&str> = outcome
            .alternate_forms
            .iter()
            .map(|f| f.label.as_str())
            .collect();
        assert!(!labels.contains(&"Factored"));
    }

    // ---------- steps (Educational Mode) ----------

    #[test]
    fn test_steps_are_returned_only_when_requested() {
        let quiet = transform("2x + 3x", SymbolicOperation::Simplify, Some("x"), false).unwrap();
        assert!(
            quiet.steps.is_none(),
            "steps computed even though they were not asked for"
        );

        let traced = transform("2x + 3x", SymbolicOperation::Simplify, Some("x"), true).unwrap();
        let steps = traced.steps.expect("steps were requested but not returned");
        assert!(!steps.trim().is_empty());
        assert_eq!(traced.value, "5*x", "tracing changed the result");
    }

    #[test]
    fn test_steps_are_never_empty_when_requested() {
        // The parser canonicalises as it reads, so most inputs produce no
        // rewrite rules and hence an empty trace. The steps block must still
        // say something true rather than render an empty box.
        for input in ["2x + 3x", "sin(x)^2 + cos(x)^2", "x/x", "sqrt(8)"] {
            let outcome = transform(input, SymbolicOperation::Simplify, Some("x"), true).unwrap();
            let steps = outcome
                .steps
                .unwrap_or_else(|| panic!("no steps produced for {input}"));
            assert!(!steps.trim().is_empty(), "empty steps block for {input}");
            assert!(
                steps.contains("as entered:"),
                "steps for {input} should show what was entered: {steps}"
            );
        }
    }

    #[test]
    fn test_steps_show_real_rules_when_they_fire() {
        // sin^2 + cos^2 -> 1 is a genuine rewrite, so the rule must be named.
        let outcome =
            transform("sin(x)^2 + cos(x)^2", SymbolicOperation::Simplify, Some("x"), true).unwrap();
        assert_eq!(outcome.value, "1");
        let steps = outcome.steps.unwrap();
        assert!(
            steps.contains("pythagorean"),
            "expected the fired rule to be named, got: {steps}"
        );
    }

    // ---------- errors ----------

    #[test]
    fn test_empty_expression_is_rejected() {
        let error = transform("   ", SymbolicOperation::Simplify, None, false).unwrap_err();
        assert!(matches!(error, SymbolicError::EmptyExpression));
        assert_eq!(error.kind(), SymbolicErrorKind::Input);
    }

    #[test]
    fn test_invalid_syntax_is_an_input_error() {
        let error = transform("x^^2 +", SymbolicOperation::Simplify, None, false).unwrap_err();
        assert_eq!(error.kind(), SymbolicErrorKind::Input);
        assert!(
            error.suggestion().is_some(),
            "an input error should offer a follow-up hint"
        );
    }

    #[test]
    fn test_oversized_expression_hits_the_documented_cap() {
        let huge = "x".repeat(MAX_EXPRESSION_CHARS + 1);
        let error = transform(&huge, SymbolicOperation::Simplify, None, false).unwrap_err();
        assert!(matches!(error, SymbolicError::TooLarge(_)));
        assert_eq!(error.kind(), SymbolicErrorKind::TooLarge);
    }

    #[test]
    fn test_operation_names_are_case_insensitive_and_aliased() {
        assert_eq!(
            SymbolicOperation::from_name("SIMPLIFY").unwrap(),
            SymbolicOperation::Simplify
        );
        assert_eq!(
            SymbolicOperation::from_name(" Factorize ").unwrap(),
            SymbolicOperation::Factor
        );
    }

    #[test]
    fn test_unknown_operation_names_the_supported_set() {
        let error = SymbolicOperation::from_name("teleport").unwrap_err();
        assert_eq!(error.kind(), SymbolicErrorKind::Unsupported);
        assert!(
            error.to_string().contains("teleport"),
            "the message should say what was not understood: {}",
            error
        );
    }

    #[test]
    fn test_no_error_message_leaks_backend_terminology() {
        // Errors cross the FFI boundary as plain strings. Guard the contract
        // that no backend crate or Rust type name reaches the UI.
        let cases = [
            transform("", SymbolicOperation::Simplify, None, false)
                .map(|_| ()),
            transform("x^^", SymbolicOperation::Simplify, None, false).map(|_| ()),
            SymbolicOperation::from_name("nope").map(|_| ()),
            transform("6", SymbolicOperation::Factor, None, false).map(|_| ()),
        ];
        for case in cases {
            let error = case.unwrap_err().to_string();
            for leaked in ["Symplex", "symplex", "Ex", "Expr", "BigInt", "None", "SymplexError"] {
                assert!(
                    !error.contains(leaked),
                    "error message leaked backend term '{}': {}",
                    leaked,
                    error
                );
            }
        }
    }
}
