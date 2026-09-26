use symplex::eq::Equation;
use symplex::prelude::{Context, Ex, SymplexError};

use crate::shared::error::CommonError;
use crate::symbolic::error::SymbolicError;
use crate::symbolic::evaluator::MAX_EXPRESSION_CHARS;

/// How many solutions an equation has.
///
/// A distinct type rather than a count, because "no solution" and "infinitely
/// many" are mathematically different answers and neither is a failure. They
/// must not be rendered as an error, and they must not be flattened into an
/// empty list that looks like a computation that did not finish.
///
/// Named apart from the bridge's `SolutionKind` on purpose: flutter_rust_bridge
/// keys generated objects by name, and two public types sharing one name make
/// it pick arbitrarily between them.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SolutionCategory {
    /// Exactly one solution, rendered like any other single value.
    Unique,
    /// A finite set of more than one solution.
    Multiple,
    /// Every value of the variable works.
    Infinite,
    /// Nothing satisfies the equation.
    None,
}

/// The outcome of solving an equation.
#[derive(Debug, Clone)]
pub struct SolveOutcome {
    /// The verified solutions, as written expressions.
    ///
    /// Empty unless [kind](Self::kind) is `Unique` or `Multiple`.
    pub solutions: Vec<String>,
    /// Which of the four outcomes this is.
    pub kind: SolutionCategory,
    /// A short qualifier, e.g. that candidate roots were discarded.
    pub details: Option<String>,
    /// Step-by-step working. The solver reports progress through results rather
    /// than rule firings, so this is only the entered/result pairing.
    pub steps: Option<String>,
}

/// Splits an equation at its first `=`.
///
/// `=` is not otherwise part of the expression grammar, so the first one is
/// always the relation. A second one means the input is not a single equation,
/// which is refused rather than silently resolved to one of them.
fn split_equation(input: &str) -> Result<(&str, &str), SymbolicError> {
    let (lhs, rhs) = input.split_once('=').ok_or(SymbolicError::NotEquation)?;

    if rhs.contains('=') {
        return Err(SymbolicError::InvalidExpression(
            "an equation has exactly one '='; this has more".to_string(),
        ));
    }
    if lhs.trim().is_empty() || rhs.trim().is_empty() {
        return Err(SymbolicError::InvalidExpression(
            "one side of the '=' is empty".to_string(),
        ));
    }
    Ok((lhs, rhs))
}

/// Solves `equation` for `variable`.
///
/// Every candidate the solver proposes is substituted back and kept only if it
/// genuinely satisfies the equation. This is not belt-and-braces: solvers reach
/// their answers by manipulating the equation, and that routinely introduces
/// roots that satisfy the rearranged form but not the original. `sqrt(x) = -1`
/// is the textbook case — squaring yields `x = 1`, which does not satisfy the
/// equation it came from. Presenting that as a solution would be showing a
/// confidently wrong answer, so it is discarded and the equation is reported as
/// having none.
pub fn solve(equation: &str, variable: Option<&str>, show_steps: bool) -> Result<SolveOutcome, SymbolicError> {
    let trimmed = equation.trim();
    if trimmed.is_empty() {
        return Err(SymbolicError::EmptyExpression);
    }
    if trimmed.chars().count() > MAX_EXPRESSION_CHARS {
        return Err(SymbolicError::TooLarge(format!(
            "over {} characters",
            MAX_EXPRESSION_CHARS
        )));
    }

    let (lhs_src, rhs_src) = split_equation(trimmed)?;

    let variable = variable
        .map(str::trim)
        .filter(|name| !name.is_empty())
        .ok_or(SymbolicError::NoVariable)?;

    let ctx = Context::new();
    let parse = |src: &str| {
        ctx.parse(src)
            .map_err(|e| SymbolicError::from(CommonError::InvalidExpression(e.to_string())))
    };

    let lhs = parse(lhs_src)?;
    let rhs = parse(rhs_src)?;
    let target = ctx
        .try_symbol(variable)
        .map_err(|_| SymbolicError::InvalidExpression(format!("'{}' is not a usable variable name", variable)))?;

    match Equation::new(lhs.clone(), rhs.clone()).solve(&target) {
        Ok(candidates) => {
            let (verified, discarded) = verify(&lhs, &rhs, &target, &candidates);

            let kind = match verified.len() {
                0 => SolutionCategory::None,
                1 => SolutionCategory::Unique,
                _ => SolutionCategory::Multiple,
            };

            Ok(SolveOutcome {
                solutions: verified,
                kind,
                details: discarded_detail(discarded),
                steps: show_steps.then(|| solution_steps(lhs_src, rhs_src, variable)),
            })
        }
        // Both are answers, not failures: every value works, or none does.
        //
        // Neither carries a qualifier here. The UI already states which of the
        // four outcomes it is, and a `details` line restating that would just
        // print the same sentence twice. A qualifier is reserved for something
        // the UI cannot know by itself, such as a discarded candidate.
        Err(SymplexError::InfiniteSolutions { .. }) => Ok(SolveOutcome {
            solutions: Vec::new(),
            kind: SolutionCategory::Infinite,
            details: None,
            steps: show_steps.then(|| solution_steps(lhs_src, rhs_src, variable)),
        }),
        Err(SymplexError::NoSolution { .. }) => Ok(SolveOutcome {
            solutions: Vec::new(),
            kind: SolutionCategory::None,
            details: None,
            steps: show_steps.then(|| solution_steps(lhs_src, rhs_src, variable)),
        }),
        Err(other) => Err(SymbolicError::from(other)),
    }
}

/// Substitutes each candidate back in and keeps the ones that hold.
///
/// Returns the survivors and how many were thrown away. A candidate only passes
/// if its residual simplifies to exactly zero — not "close to", not numerically
/// equal, exactly zero, because the arithmetic here is exact.
fn verify(lhs: &Ex, rhs: &Ex, variable: &Ex, candidates: &[Ex]) -> (Vec<String>, usize) {
    let mut verified = Vec::with_capacity(candidates.len());
    let mut discarded = 0;

    for candidate in candidates {
        let residual = (&lhs.subs(variable, candidate) - &rhs.subs(variable, candidate)).simplify();
        if residual.is_zero_structural() {
            verified.push(candidate.to_string());
        } else {
            discarded += 1;
        }
    }

    (verified, discarded)
}

/// Explains a discarded candidate, so a quietly shorter answer is not mistaken
/// for the whole truth.
fn discarded_detail(discarded: usize) -> Option<String> {
    if discarded == 0 {
        return None;
    }
    let noun = if discarded == 1 { "candidate" } else { "candidates" };
    let pronoun = if discarded == 1 { "it" } else { "they" };
    Some(format!(
        "{} {} discarded: {} did not satisfy the original equation",
        discarded, noun, pronoun
    ))
}

/// Renders the entered equation and its solutions as working.
///
/// Solving reports progress through successive results rather than individual
/// rule firings, so there is no rule trace to show; the equation and what came
/// out of it are the honest record.
fn solution_steps(lhs: &str, rhs: &str, variable: &str) -> String {
    format!(
        "equation:  {} = {}\nsolve for: {variable}",
        lhs.trim(),
        rhs.trim()
    )
}
