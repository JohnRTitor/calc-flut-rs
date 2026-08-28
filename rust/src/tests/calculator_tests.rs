use {
    crate::calculator::{evaluator, parser},
    std::{
        collections::HashMap,
        f64::consts::{E, PI},
    },
};

// Base evaluation function that returns the raw Result
fn evaluate_core(
    expr: &str,
    is_degree: bool,
    ans_value: f64,
) -> Result<crate::calculator::rational::CalcValue, crate::calculator::error::CalcError> {
    let tokens = parser::tokenize(expr)?;
    let mut p = parser::Parser::new(&tokens);
    let ast = p.parse()?;
    let evaluator = evaluator::BasicEvaluator::new(is_degree, ans_value);
    evaluator::evaluate_expr(&ast, &evaluator)
}

// Convenience: evaluates to f64 with default state (radians, ans = 0)
fn eval(expr: &str) -> f64 {
    evaluate_core(expr, false, 0.0).unwrap().to_float()
}

// Convenience: evaluates to f64 with custom state
fn eval_with_state(expr: &str, is_degree: bool, ans_value: f64) -> f64 {
    evaluate_core(expr, is_degree, ans_value)
        .unwrap()
        .to_float()
}

// Convenience: evaluates to Result (useful for testing expected errors)
fn eval_result(
    expr: &str,
    is_degree: bool,
) -> Result<crate::calculator::rational::CalcValue, crate::calculator::error::CalcError> {
    evaluate_core(expr, is_degree, 0.0)
}

#[test]
fn test_basic_arithmetic() {
    assert_eq!(eval("2+2"), 4.0);
    assert_eq!(eval("10-3*2"), 4.0);
    assert_eq!(eval("(10-3)*2"), 14.0);
    assert_eq!(eval("10/2"), 5.0);
    assert_eq!(eval("10mod3"), 1.0);
    assert_eq!(eval("-5+2"), -3.0);
    assert_eq!(eval("3.14+0.86"), 4.0);
    assert_eq!(eval("0-0"), 0.0);
}

#[test]
fn test_operator_precedence() {
    assert_eq!(eval("-2^2"), -4.0); // Unary negation is lower precedence than exponentiation
    assert_eq!(eval("2^3^2"), 512.0); // Right-associativity of exponentiation
    assert_eq!(eval("10+2*3-4/2"), 14.0);
    assert_eq!(eval("5+5!"), 125.0);
    assert_eq!(eval("3!+2"), 8.0);
    assert_eq!(eval("-(2+3)"), -5.0);
}

#[test]
fn test_modular_exponentiation() {
    assert_eq!(eval("17^22 mod 21"), 4.0);
    assert_eq!(eval("2^10 mod 1000"), 24.0);
    assert_eq!(eval("5^117 mod 19"), 1.0);
    assert_eq!(eval("7^128 mod 13"), 3.0);
    assert_eq!(eval("3^0 mod 7"), 1.0);
}

#[test]
fn test_large_integers() {
    let result = evaluate_core("2^100", false, 0.0).unwrap();
    if let crate::calculator::rational::CalcValue::Rational(r) = result {
        assert_eq!(r.numer().to_string(), "1267650600228229401496703205376");
    } else {
        panic!("Expected Rational");
    }

    let result2 = evaluate_core("50!", false, 0.0).unwrap();
    if let crate::calculator::rational::CalcValue::Rational(r) = result2 {
        assert_eq!(
            r.numer().to_string(),
            "30414093201713378043612608166064768844377641568960512000000000000"
        );
    } else {
        panic!("Expected Rational for Factorial");
    }
}

#[test]
fn test_implicit_multiplication() {
    assert_eq!(eval("2(3+4)"), 14.0);
    assert_eq!(eval("(2+3)(4+5)"), 45.0);
    assert_eq!(eval("2π"), 2.0 * PI);
    assert_eq!(eval("3e"), 3.0 * E);
    assert_eq!(eval("2sqrt(16)"), 8.0);
    assert_eq!(eval("3sin(π/2)"), 3.0);
}

#[test]
fn test_scientific() {
    assert!((eval("sin(π/2)") - 1.0).abs() < 1e-10);
    assert!((eval("cos(0)") - 1.0).abs() < 1e-10);
    assert_eq!(eval("log(100)"), 2.0);
    assert_eq!(eval("ln(e)"), 1.0);
    assert_eq!(eval("sqrt(16)"), 4.0);
    assert_eq!(eval("5!"), 120.0);
    assert_eq!(eval("2^3"), 8.0);
    assert!((eval("tan(π/4)") - 1.0).abs() < 1e-10);
}

#[test]
fn test_exponential_notation() {
    assert_eq!(eval("1e3"), 1000.0);
    assert_eq!(eval("2.5e-2"), 0.025);
    assert_eq!(eval("1E3"), 1000.0);
    assert_eq!(eval("-1e2"), -100.0);
}

#[test]
fn test_trig_modes() {
    assert!((eval_with_state("sin(90)", true, 0.0) - 1.0).abs() < 1e-10);
    assert!((eval_with_state("sin(π/2)", false, 0.0) - 1.0).abs() < 1e-10);
    assert!((eval_with_state("asin(1)", true, 0.0) - 90.0).abs() < 1e-10);
    assert!((eval_with_state("asin(1)", false, 0.0) - PI / 2.0).abs() < 1e-10);
    assert!((eval_with_state("cos(180)", true, 0.0) - -1.0).abs() < 1e-10);
    assert!((eval_with_state("cos(π)", false, 0.0) - -1.0).abs() < 1e-10);
    assert!((eval_with_state("tan(45)", true, 0.0) - 1.0).abs() < 1e-10);
}

#[test]
fn test_hyperbolic() {
    assert_eq!(eval("sinh(0)"), 0.0);
    assert_eq!(eval("cosh(0)"), 1.0);
    assert_eq!(eval("tanh(0)"), 0.0);
    assert!((eval("asinh(0)") - 0.0).abs() < 1e-10);
    assert!((eval("acosh(1)") - 0.0).abs() < 1e-10);
    assert!((eval("atanh(0)") - 0.0).abs() < 1e-10);
}

#[test]
fn test_ans() {
    assert_eq!(eval_with_state("5+ans", false, 10.0), 15.0);
    assert_eq!(eval_with_state("ans*2", false, 21.0), 42.0);
    assert_eq!(eval_with_state("ans", false, 42.0), 42.0);
    assert_eq!(eval_with_state("-ans", false, 42.0), -42.0);
}

#[test]
fn test_edge_cases() {
    assert!(matches!(
        eval_result("1/0", false),
        Err(crate::calculator::error::CalcError::DivisionByZero)
    ));
    assert!(matches!(
        eval_result("1/cos(90)", true),
        Err(crate::calculator::error::CalcError::DivisionByZero)
    ));
    assert!(matches!(
        eval_result("tan(90)", true),
        Err(crate::calculator::error::CalcError::DomainError(_))
    ));
    assert!(matches!(
        eval_result("sqrt(-1)", false),
        Err(crate::calculator::error::CalcError::DomainError(_))
    ));
    assert!(matches!(
        eval_result("asin(2)", false),
        Err(crate::calculator::error::CalcError::DomainError(_))
    ));
    assert!(matches!(
        eval_result("0/0", false),
        Err(crate::calculator::error::CalcError::DivisionByZero)
    ));

    assert_eq!(eval_with_state("cos(90)", true, 0.0), 0.0);
    assert_eq!(eval_with_state("sin(180)", true, 0.0), 0.0);
    assert_eq!(eval_with_state("tan(180)", true, 0.0), 0.0);
}

#[test]
fn test_complex_expressions() {
    assert!((eval("sin(π/2)^2 + cos(π/2)^2") - 1.0).abs() < 1e-10);
    assert_eq!(eval("(2^3)^2"), 64.0);
    assert_eq!(eval("10+2*3-4/2"), 14.0);
    assert_eq!(eval("sqrt(144) + 5!"), 132.0);
}

#[test]
fn test_variables() {
    let mut vars = HashMap::new();
    vars.insert("x".to_string(), 5.0);
    vars.insert("y".to_string(), 3.0);
    vars.insert("radius".to_string(), 10.0);

    let func_eval = evaluator::FunctionEvaluator::new(vars, false, 0.0);

    let expr = parser::Parser::new(&parser::tokenize("x^2 + y^2").unwrap())
        .parse()
        .unwrap();
    assert_eq!(
        evaluator::evaluate_expr(&expr, &func_eval)
            .unwrap()
            .to_float(),
        34.0
    );

    let expr2 = parser::Parser::new(&parser::tokenize("pi * radius^2").unwrap())
        .parse()
        .unwrap();
    assert!(
        (evaluator::evaluate_expr(&expr2, &func_eval)
            .unwrap()
            .to_float()
            - 314.159265)
            .abs()
            < 1e-5
    );

    let expr_err = parser::Parser::new(&parser::tokenize("x + z").unwrap())
        .parse()
        .unwrap();
    assert!(matches!(
        evaluator::evaluate_expr(&expr_err, &func_eval),
        Err(crate::calculator::error::CalcError::UnknownVariable(_))
    ));
}

#[test]
fn test_variable_extraction() {
    let expr = parser::Parser::new(&parser::tokenize("x^2 + y^2 + sin(x) + e^z").unwrap())
        .parse()
        .unwrap();
    let vars = evaluator::extract_variables(&expr);
    assert_eq!(vars.len(), 3);
    assert!(vars.contains("x"));
    assert!(vars.contains("y"));
    assert!(vars.contains("z"));
    assert!(!vars.contains("e"));
    assert!(!vars.contains("sin"));
}

#[test]
fn test_structured_errors() {
    assert!(matches!(
        eval_result("2 + ", false),
        Err(crate::calculator::error::CalcError::MissingOperand(_))
    ));
    assert!(matches!(
        eval_result("(2 + 3", false),
        Err(crate::calculator::error::CalcError::MissingClosingParenthesis)
    ));
    assert!(matches!(
        eval_result("2 & 3", false),
        Err(crate::calculator::error::CalcError::InvalidToken(_))
    ));
    assert!(matches!(
        eval_result("", false),
        Err(crate::calculator::error::CalcError::MissingOperand(_))
    ));
}
