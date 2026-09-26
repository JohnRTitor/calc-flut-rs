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
        let needs_variable = operation.requires_variable();
        transform(
            expression,
            operation,
            needs_variable.then_some("x"),
            false,
        )
        .map(|outcome| outcome.value)
    }

    /// Differentiates `expression` with respect to `variable`.
    fn diff(expression: &str, variable: &str) -> String {
        transform(
            expression,
            SymbolicOperation::Differentiate,
            Some(variable),
            false,
        )
        .expect("differentiation should succeed")
        .value
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

    // ---------- integrate ----------

    /// Integrates `expression` with respect to `variable`.
    fn integrate(expression: &str, variable: &str) -> String {
        transform(
            expression,
            SymbolicOperation::Integrate,
            Some(variable),
            false,
        )
        .expect("integration should succeed")
        .value
    }

    /// Whether differentiating the antiderivative returns the integrand.
    ///
    /// Only usable when simplification can close the loop, so it is applied to
    /// the tractable cases in the tests below and deliberately not used as a
    /// runtime gate — see `test_simplification_cannot_always_verify_a_good_answer`.
    fn is_antiderivative_of(integrand: &str, antiderivative: &str) -> bool {
        let ctx = symplex::prelude::Context::new();
        let x = ctx.symbol("x");
        let f = ctx.parse(integrand).unwrap();
        let a = ctx.parse(antiderivative).unwrap();
        a.diff(&x).simplify() == f.simplify()
    }

    /// Integrands whose antiderivatives involve `ln(abs(..))`.
    ///
    /// Differentiating an absolute value introduces `sign`/`abs` pairs that
    /// simplification will not reduce, so these cannot be checked by
    /// differentiating back even though the answers are right.
    const UNVERIFIABLE: [&str; 3] = ["1/x", "tan(x)", "1/(x^2 - 1)"];

    #[test]
    fn test_integrate_power_rule() {
        assert_eq!(integrate("x^2", "x"), "1/3*x^3 + C");
        assert_eq!(integrate("x^3+x", "x"), "1/4*x^4 + 1/2*x^2 + C");
    }

    #[test]
    fn test_integrate_keeps_exact_fractions() {
        // Must not decay to a decimal.
        assert_eq!(integrate("1/3", "x"), "1/3*x + C");
        assert!(integrate("x", "x").contains("1/2"));
    }

    #[test]
    fn test_integrate_trigonometric_and_exponential() {
        assert!(is_antiderivative_of("sin(x)", &integrate("sin(x)", "x")));
        assert!(is_antiderivative_of("cos(x)", &integrate("cos(x)", "x")));
        assert!(is_antiderivative_of("exp(x)", &integrate("exp(x)", "x")));
        assert!(is_antiderivative_of(
            "exp(-x^2)",
            &integrate("exp(-x^2)", "x")
        ));
    }

    #[test]
    fn test_integrate_special_functions() {
        // The ones a textbook student actually meets, checked by differentiating
        // back: sqrt, 1/(1+x^2), 1/x^2, and a product needing by parts.
        for integrand in ["sqrt(x)", "1/(1 + x^2)", "1/x^2", "x*exp(x)", "ln(x)"] {
            let antiderivative = integrate(integrand, "x");
            assert!(
                is_antiderivative_of(integrand, &antiderivative),
                "d/dx of {antiderivative} did not give {integrand}"
            );
        }
    }

    #[test]
    fn test_every_checkable_antiderivative_differentiates_back() {
        for integrand in [
            "x^2", "x^3+x", "sin(x)", "cos(x)", "exp(x)", "sqrt(x)",
            "1/(1 + x^2)", "1/x^2", "x*exp(x)", "ln(x)", "sec(x)^2", "2^x",
        ] {
            let antiderivative = integrate(integrand, "x");
            assert!(
                is_antiderivative_of(integrand, &antiderivative),
                "{integrand}: d/dx of {antiderivative} is not {integrand}"
            );
        }
    }

    #[test]
    fn test_simplification_cannot_always_verify_a_good_answer() {
        // Why the runtime path has no residual check, unlike solving. The
        // antiderivatives of these are correct, but differentiating them
        // introduces sign/abs terms that simplify will not reduce, so a residual
        // gate would reject correct mathematics.
        for integrand in UNVERIFIABLE {
            let antiderivative = integrate(integrand, "x");
            assert!(
                !is_antiderivative_of(integrand, &antiderivative),
                "{integrand} unexpectedly verified; if simplify has improved, the \
                 runtime residual check can be reconsidered"
            );
        }
    }

    #[test]
    fn test_indefinite_integral_states_the_arbitrary_constant() {
        // Reporting one member of the family and stopping would present an
        // incomplete answer as a complete one.
        let value = integrate("x^2", "x");
        assert!(
            value.ends_with("+ C"),
            "the constant must be part of the value, not just mentioned: {value}"
        );
    }

    #[test]
    fn test_indefinite_integral_explains_the_constant() {
        let outcome =
            transform("x^2", SymbolicOperation::Integrate, Some("x"), false).unwrap();
        let details = outcome.details.expect("the constant must be explained");
        assert!(
            details.contains('C'),
            "expected the qualifier to name the constant, got: {details}"
        );
    }

    #[test]
    fn test_integrate_refuses_what_it_cannot_do() {
        // Neither a factorial nor x^x has an elementary antiderivative. The
        // backend hands both back unevaluated, which must become a refusal
        // rather than the notation Integral(x!, x) reaching the UI.
        for integrand in ["x!", "x^x"] {
            let error =
                transform(integrand, SymbolicOperation::Integrate, Some("x"), false)
                    .unwrap_err();
            assert!(matches!(error, SymbolicError::NotSupported(_)), "{integrand}");
            let message = error.to_string();
            assert!(
                !message.contains("Integral("),
                "unevaluated backend notation leaked: {message}"
            );
        }
    }

    #[test]
    fn test_integrate_without_a_variable_is_refused() {
        let error = transform("x^2", SymbolicOperation::Integrate, None, false).unwrap_err();
        assert!(matches!(error, SymbolicError::NoVariable));
    }

    #[test]
    fn test_antiderivative_is_not_offered_as_an_alternate_form() {
        let outcome =
            transform("x^2", SymbolicOperation::Integrate, Some("x"), false).unwrap();
        let labels: Vec<&str> = outcome
            .alternate_forms
            .iter()
            .map(|f| f.label.as_str())
            .collect();
        assert!(!labels.contains(&"Antiderivative"));
        // What it does offer are forms of the original input.
        for form in &outcome.alternate_forms {
            assert_ne!(form.expression, outcome.value);
        }
    }

    #[test]
    fn test_transforms_have_steps_even_without_a_rule_trace() {
        // Nothing but simplification can name the rules it fired, so the other
        // operations fall back to the entered and resulting forms. The block must
        // never be empty just because no trace was available.
        let outcome =
            transform("x^2", SymbolicOperation::Integrate, Some("x"), true).unwrap();
        let steps = outcome.steps.expect("steps were requested");
        assert!(steps.contains("as entered:"), "got: {steps}");
        assert!(steps.contains('x'), "should name the variable: {steps}");

        let diff =
            transform("x^2", SymbolicOperation::Differentiate, Some("x"), true).unwrap();
        assert!(diff.steps.expect("steps were requested").contains("as entered:"));
    }

    #[test]
    fn test_transforms_have_no_steps_unless_requested() {
        let outcome =
            transform("x^2", SymbolicOperation::Integrate, Some("x"), false).unwrap();
        assert!(outcome.steps.is_none());
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

    // ---------- differentiate ----------

    #[test]
    fn test_differentiate_power_rule() {
        assert_eq!(diff("x^3 + x", "x"), "3*x^2 + 1");
        assert_eq!(diff("(x + 1)^5", "x"), "5*(x + 1)^4");
    }

    #[test]
    fn test_differentiate_reciprocal_and_root() {
        assert_eq!(diff("1/x", "x"), "-x^(-2)");
        assert_eq!(diff("sqrt(x)", "x"), "1/(2*sqrt(x))");
    }

    #[test]
    fn test_differentiate_applies_the_product_and_chain_rules() {
        // x^2*sin(x) needs both, and this exact value is the classic
        // worked example for them.
        assert_eq!(diff("x^2*sin(x)", "x"), "x^2*cos(x) + 2*x*sin(x)");
        assert_eq!(diff("exp(x^2)", "x"), "2*x*exp(x^2)");
    }

    #[test]
    fn test_differentiate_with_respect_to_one_of_several_variables() {
        // These are partial derivatives: the other variable is a constant.
        assert_eq!(diff("x^2*y^3", "x"), "2*x*y^3");
        assert_eq!(diff("x^2*y^3", "y"), "3*x^2*y^2");
    }

    #[test]
    fn test_differentiate_by_an_absent_variable_is_zero_not_an_error() {
        // d/dy(x^2) is 0. Refusing this would be wrong, not cautious.
        assert_eq!(diff("x^2", "y"), "0");
    }

    #[test]
    fn test_differentiate_without_a_variable_is_refused() {
        let error = transform("x^2", SymbolicOperation::Differentiate, None, false).unwrap_err();
        assert!(matches!(error, SymbolicError::NoVariable));
    }

    #[test]
    fn test_differentiate_refuses_what_it_cannot_do() {
        // The derivative of a factorial has no symbolic form. The backend hands
        // the request back unevaluated, which must become an explicit refusal
        // rather than the notation `Derivative(x!, x)` reaching the UI.
        let error =
            transform("x!", SymbolicOperation::Differentiate, Some("x"), false).unwrap_err();
        assert!(matches!(error, SymbolicError::NotSupported(_)));
        assert_eq!(error.kind(), SymbolicErrorKind::Unsupported);
        let message = error.to_string();
        assert!(
            !message.contains("Derivative("),
            "unevaluated backend notation leaked into the message: {message}"
        );
    }

    #[test]
    fn test_derivative_is_not_offered_as_an_alternate_form() {
        // The derivative is a different expression, not another way of writing
        // the input, so it must never appear among the input's forms.
        let outcome = transform(
            "x^2 + 1",
            SymbolicOperation::Differentiate,
            Some("x"),
            false,
        )
        .unwrap();
        assert_eq!(outcome.value, "2*x");

        let labels: Vec<&str> = outcome
            .alternate_forms
            .iter()
            .map(|f| f.label.as_str())
            .collect();
        assert!(!labels.contains(&"Derivative"));

        // What it does offer are forms of the original input.
        for form in &outcome.alternate_forms {
            assert_ne!(form.expression, outcome.value);
        }
    }

    #[test]
    fn test_form_operations_are_the_ones_offered_as_forms() {
        // Guards the partition itself: anything added to ALL must be
        // deliberately classified as a form or explicitly not.
        let forms: Vec<&str> = crate::symbolic::evaluator::FORM_OPERATIONS
            .iter()
            .map(|op| op.label())
            .collect();
        assert_eq!(forms, vec!["Simplified", "Expanded", "Factored"]);
        for operation in SymbolicOperation::ALL {
            let is_transform = matches!(
                operation,
                SymbolicOperation::Differentiate | SymbolicOperation::Integrate
            );
            assert_eq!(
                operation.is_form(),
                !is_transform,
                "{operation:?} was not classified"
            );
        }
    }

    #[test]
    fn test_operations_needing_a_variable_are_declared_consistently() {
        for operation in SymbolicOperation::ALL {
            let needs_variable = operation.requires_variable();
            assert_eq!(
                operation.requires_variable(),
                matches!(
                    operation,
                    SymbolicOperation::Factor
                        | SymbolicOperation::Differentiate
                        | SymbolicOperation::Integrate
                ),
                "{operation:?} disagreed about needing a variable"
            );
            if !needs_variable {
                continue;
            }
            // Anything that needs a variable must say so rather than quietly
            // acting on a guess.
            let error = transform("1", operation, None, false).unwrap_err();
            assert!(matches!(error, SymbolicError::NoVariable));
        }
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
