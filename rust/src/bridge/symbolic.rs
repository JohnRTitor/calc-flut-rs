//! Asynchronous bridge surface for symbolic (CAS) operations.
//!
//! Every function here intentionally omits `#[frb(sync)]`, unlike the rest of
//! the bridge. Symbolic simplification, expansion and factorisation have no
//! predictable upper bound on their runtime, and a synchronous FFI call would
//! block the Flutter UI thread — freezing the keypad and risking an Android
//! ANR. Omitting the attribute makes flutter_rust_bridge dispatch the work off
//! the calling thread and hand Dart a `Future`.
//!
//! Errors cross the boundary as a structured [`SymbolicErrorInfo`] rather than
//! a bare `String`, so the Dart side never has to string-scrub wrapper syntax
//! out of a message to display it.

use flutter_rust_bridge::frb;

use crate::symbolic::error::{SymbolicError, SymbolicErrorKind};
use crate::symbolic::evaluator::{self, LimitRange, SymbolicOperation};
use crate::symbolic::matrix::MatrixSpec as CoreMatrixSpec;
use crate::symbolic::solve::{self, SolutionCategory};

/// A structured error, safe to display verbatim.
///
/// [kind] lets the UI distinguish "you typed something wrong" from "that is
/// genuinely too big to do", and drives whether the app's Learn More
/// limitation banner is shown alongside the message.
#[frb]
pub struct SymbolicErrorInfo {
    /// A short, stable category: `input`, `unsupported`, `computation` or
    /// `too_large`.
    pub kind: String,
    /// The message to show, already in plain English.
    pub message: String,
    /// An optional short follow-up hint, or `None` when the message already
    /// explains itself.
    pub suggestion: Option<String>,
}

impl From<&SymbolicError> for SymbolicErrorInfo {
    fn from(error: &SymbolicError) -> Self {
        SymbolicErrorInfo {
            kind: match error.kind() {
                SymbolicErrorKind::Input => "input",
                SymbolicErrorKind::Unsupported => "unsupported",
                SymbolicErrorKind::Computation => "computation",
                SymbolicErrorKind::TooLarge => "too_large",
            }
            .to_string(),
            message: error.to_string(),
            suggestion: error.suggestion(),
        }
    }
}

/// The two ends of a definite integral.
///
/// One value rather than two optional strings, so half a range cannot be
/// expressed by accident from the Dart side either.
#[frb]
pub struct Bounds {
    /// The lower limit, as typed.
    pub lower: String,
    /// The upper limit, as typed.
    pub upper: String,
}

/// One alternative representation of the same expression, offered as a
/// tappable chip under the primary result.
#[frb]
pub struct AlternateForm {
    /// The form's name, e.g. `Expanded`.
    pub label: String,
    /// The expression written in that form.
    pub expression: String,
}

/// The result of a symbolic operation.
#[frb]
pub struct SymbolicResult {
    /// The requested form, as the primary value.
    pub value: String,
    /// The remaining forms of the same expression, computed in the same call so
    /// switching form costs no extra round trip.
    pub alternate_forms: Vec<AlternateForm>,
    /// A short qualifier, e.g. that factorisation found nothing to pull out.
    pub details: Option<String>,
    /// Step-by-step working, present only when `show_steps` was requested.
    pub steps: Option<String>,
}

/// The symbolic operations this build supports, for the reference dialog.
///
/// Returning them from Rust keeps the list a single source of truth rather than
/// a hand-maintained literal in the UI that can drift from the parser above.
#[frb(sync)]
pub fn symbolic_operations() -> Vec<String> {
    SymbolicOperation::ALL
        .iter()
        .map(|op| op.verb().to_string())
        .collect()
}

/// Applies a symbolic operation to `expression`.
///
/// `operation` is one of `simplify`, `expand`, `factor` or `differentiate`.
/// `variable` names the variable to act on for the operations that need one;
/// pass an empty string (or `None`) when it is not needed or not yet chosen.
/// `bounds` is the range a definite integral runs over, and is ignored by
/// everything else. It is a single optional value so Dart cannot express "a
/// lower bound but no upper one", which is not a weaker request but a different
/// question. `show_steps` mirrors the existing `modular_evaluate` parameter and
/// is gated by Educational Mode.
///
/// Runs off the UI thread; see the module docs.
#[frb]
pub async fn symbolic_transform(
    expression: String,
    operation: String,
    variable: Option<String>,
    bounds: Option<Bounds>,
    show_steps: bool,
) -> Result<SymbolicResult, SymbolicErrorInfo> {
    let operation = SymbolicOperation::from_name(&operation)
        .map_err(|e| SymbolicErrorInfo::from(&e))?;

    evaluator::transform(
        &expression,
        operation,
        variable.as_deref(),
        bounds.as_ref().map(|b| LimitRange::new(b.lower.clone(), b.upper.clone())).as_ref(),
        show_steps,
    )
        .map(|outcome| SymbolicResult {
            value: outcome.value,
            alternate_forms: outcome
                .alternate_forms
                .into_iter()
                .map(|form| AlternateForm {
                    label: form.label,
                    expression: form.expression,
                })
                .collect(),
            details: outcome.details,
            steps: outcome.steps,
        })
        .map_err(|e| SymbolicErrorInfo::from(&e))
}

/// How many solutions an equation has.
///
/// A distinct type rather than a count, so the UI can tell "there is no
/// solution" and "every value works" apart from "the solver is still working".
/// Neither of the first two is a failure, and neither may be rendered as one.
#[frb]
pub enum SolutionKind {
    /// Exactly one solution.
    Unique,
    /// A finite set of more than one solution.
    Multiple,
    /// Every value of the variable satisfies the equation.
    Infinite,
    /// Nothing satisfies the equation.
    None,
}

impl From<SolutionCategory> for SolutionKind {
    fn from(kind: SolutionCategory) -> Self {
        match kind {
            SolutionCategory::Unique => SolutionKind::Unique,
            SolutionCategory::Multiple => SolutionKind::Multiple,
            SolutionCategory::Infinite => SolutionKind::Infinite,
            SolutionCategory::None => SolutionKind::None,
        }
    }
}

/// The result of solving an equation.
///
/// A separate type from [SymbolicResult] because the shapes differ: a solution
/// set is not one value, and overloading the expression result with optional
/// fields would leave the UI guessing which combination it was looking at.
#[frb]
pub struct SymbolicSolveResult {
    /// The verified solutions, empty unless `solution_kind` is `unique` or
    /// `multiple`.
    pub solutions: Vec<String>,
    /// Which of the four outcomes this is.
    pub solution_kind: SolutionKind,
    /// A short qualifier, e.g. that candidate roots were discarded.
    pub details: Option<String>,
    /// Step-by-step working, present only when `show_steps` was requested.
    pub steps: Option<String>,
}

/// Solves the equation in `equation` for `variable`.
///
/// The equation is given as plain text containing a single `=`, exactly as the
/// user typed it. Every candidate the solver proposes is substituted back and
/// checked against the original equation before being reported, so a root
/// introduced by rearranging the equation is discarded rather than presented.
///
/// Runs off the UI thread; see the module docs.
#[frb]
pub async fn symbolic_solve(
    equation: String,
    variable: Option<String>,
    show_steps: bool,
) -> Result<SymbolicSolveResult, SymbolicErrorInfo> {
    solve::solve(&equation, variable.as_deref(), show_steps)
        .map(|outcome| SymbolicSolveResult {
            solutions: outcome.solutions,
            solution_kind: outcome.kind.into(),
            details: outcome.details,
            steps: outcome.steps,
        })
        .map_err(|e| SymbolicErrorInfo::from(&e))
}

/// One sampled point on a plotted curve.
///
/// `y` is `None` where the function is undefined. That is a hole in the curve,
/// not a value of zero, and the UI must break the line rather than join across
/// it.
#[frb]
pub struct PlotPoint {
    /// The abscissa.
    pub x: f64,
    /// The ordinate, or `None` at a gap in the curve.
    pub y: Option<f64>,
}

/// A sampled curve and the window it was taken over.
#[frb]
pub struct PlotData {
    /// The samples, in increasing `x`.
    pub points: Vec<PlotPoint>,
    /// Lower bound of the sampled window.
    pub x_min: f64,
    /// Upper bound of the sampled window.
    pub x_max: f64,
    /// Smallest plotted ordinate, for setting the vertical axis.
    pub y_min: f64,
    /// Largest plotted ordinate, for setting the vertical axis.
    pub y_max: f64,
}

/// Samples `expression` numerically for plotting.
///
/// `variable` is the symbol the curve is a function of. Values the function
/// cannot produce become gaps, and a jump across a pole opens one, so an
/// asymptote is drawn as two branches rather than a line through it.
///
/// Runs off the UI thread; see the module docs.
#[frb]
pub async fn symbolic_plot(
    expression: String,
    variable: Option<String>,
    samples: Option<u32>,
) -> Result<PlotData, SymbolicErrorInfo> {
    let count = samples
        .filter(|count| *count >= 2)
        .unwrap_or(crate::symbolic::plot::DEFAULT_SAMPLES);

    crate::symbolic::plot::plot(&expression, variable.as_deref(), count)
        .map(|data| PlotData {
            points: data
                .points
                .into_iter()
                .map(|point| PlotPoint { x: point.x, y: point.y })
                .collect(),
            x_min: data.x_min,
            x_max: data.x_max,
            y_min: data.y_min,
            y_max: data.y_max,
        })
        .map_err(|e| SymbolicErrorInfo::from(&e))
}

/// A matrix of exact entries, as entered.
#[frb]
pub struct MatrixInput {
    /// The cells, row-major. Every row must be the same length.
    pub cells: Vec<Vec<String>>,
}

/// Everything worth knowing about a matrix, in one response.
///
/// One request rather than one per quantity: a user who types a matrix wants
/// to see all of it, and six round trips would be six times the work for the
/// same answer.
#[frb]
pub struct MatrixAnalysisResponse {
    /// The determinant, when the matrix is square.
    pub determinant: Option<String>,
    /// The rank, always defined.
    pub rank: u32,
    /// The trace, when the matrix is square.
    pub trace: Option<String>,
    /// The inverse, row-major, when one exists.
    pub inverse: Option<Vec<Vec<String>>>,
    /// The reduced row-echelon form, row-major.
    pub reduced: Vec<Vec<String>>,
    /// The eigenvalues, or `None` when they could not all be determined.
    ///
    /// Absent means "could not work it out", which is not the same as "there
    /// are none" and must not be shown as an empty list.
    pub eigenvalues: Option<Vec<String>>,
    /// One representative eigenvector per *distinct* eigenvalue.
    ///
    /// Keyed by its own eigenvalue rather than listed in step with
    /// [MatrixAnalysisResponse::eigenvalues], because those two do not line up:
    /// the eigenvalues come back with multiplicity while the eigenvectors come
    /// back per distinct value.
    pub eigenvectors: Option<Vec<EigenPair>>,
    /// Facts explaining any of the above being absent.
    pub details: Option<String>,
}

/// A representative eigenvector together with the eigenvalue it belongs to.
#[frb]
pub struct EigenPair {
    /// The eigenvalue this vector belongs to.
    pub eigenvalue: String,
    /// One vector from its eigenspace, as a single row.
    pub vector: Vec<String>,
    /// How many independent vectors the eigenspace actually has, which may be
    /// more than the one shown.
    pub eigenspace_dimension: u32,
}

/// Analyses a matrix.
///
/// Every value is exact: a determinant over thirty digits comes back as thirty
/// digits, not a float that has lost the end of them.
///
/// Runs off the UI thread; see the module docs.
#[frb]
pub async fn matrix_analyse(
    input: MatrixInput,
) -> Result<MatrixAnalysisResponse, SymbolicErrorInfo> {
    crate::symbolic::matrix::analyse(&CoreMatrixSpec::new(input.cells))
        .map(|analysis| MatrixAnalysisResponse {
            determinant: analysis.determinant,
            rank: analysis.rank as u32,
            trace: analysis.trace,
            inverse: analysis.inverse,
            reduced: analysis.reduced,
            eigenvalues: analysis.eigenvalues,
            eigenvectors: analysis.eigenvectors.map(|entries| {
                entries
                    .into_iter()
                    .map(|entry| EigenPair {
                        eigenvalue: entry.eigenvalue,
                        vector: entry.vector,
                        eigenspace_dimension: entry.eigenspace_dimension as u32,
                    })
                    .collect()
            }),
            details: analysis.details,
        })
        .map_err(|e| SymbolicErrorInfo::from(&e))
}

/// One prime-power term of a factorisation.
#[frb]
pub struct PrimePower {
    /// The prime, as written. `-1` leads when the number was negative.
    pub prime: String,
    /// How many times it occurs.
    pub power: u32,
}

/// Everything worth knowing about one integer, in one response.
#[frb]
pub struct NumberAnalysisResponse {
    /// Whether it is prime. Zero, one and negatives are not.
    pub is_prime: bool,
    /// Whether it is a perfect square.
    pub is_square: bool,
    /// Whether it is a perfect number.
    pub is_perfect: bool,
    /// Whether it is a Carmichael number.
    pub is_carmichael: bool,
    /// The prime factorisation, leading with `-1` for a negative number.
    pub factors: Vec<PrimePower>,
    /// Every positive divisor, in order. Empty for zero, which has infinitely
    /// many.
    pub divisors: Vec<String>,
    /// How many divisors it has.
    pub divisor_count: u32,
    /// The sum of its divisors. Empty for zero, where the sum diverges.
    pub divisor_sum: String,
    /// Euler's totient. Empty for zero, where it is not defined.
    pub totient: String,
    /// The next prime above it.
    pub next_prime: String,
    /// The largest prime below it. Empty when there is none.
    pub previous_prime: String,
    /// Facts explaining any of the above being absent.
    pub details: Option<String>,
}

/// Analyses one integer.
///
/// Runs off the UI thread; see the module docs.
#[frb]
pub async fn number_analyse(
    number: String,
) -> Result<NumberAnalysisResponse, SymbolicErrorInfo> {
    crate::symbolic::ntheory::analyse(&number)
        .map(|analysis| NumberAnalysisResponse {
            is_prime: analysis.is_prime,
            is_square: analysis.is_square,
            is_perfect: analysis.is_perfect,
            is_carmichael: analysis.is_carmichael,
            factors: analysis
                .factors
                .into_iter()
                .map(|factor| PrimePower {
                    prime: factor.prime,
                    power: factor.power,
                })
                .collect(),
            divisors: analysis.divisors,
            divisor_count: analysis.divisor_count as u32,
            divisor_sum: analysis.divisor_sum,
            totient: analysis.totient,
            next_prime: analysis.next_prime,
            previous_prime: analysis.previous_prime,
            details: analysis.details,
        })
        .map_err(|e| SymbolicErrorInfo::from(&e))
}

/// The greatest common divisor of two integers. Never negative.
#[frb]
pub async fn number_gcd(
    first: String,
    second: String,
) -> Result<String, SymbolicErrorInfo> {
    crate::symbolic::ntheory::gcd(&first, &second)
        .map_err(|e| SymbolicErrorInfo::from(&e))
}

/// The least common multiple of two integers. Never negative.
#[frb]
pub async fn number_lcm(
    first: String,
    second: String,
) -> Result<String, SymbolicErrorInfo> {
    crate::symbolic::ntheory::lcm(&first, &second)
        .map_err(|e| SymbolicErrorInfo::from(&e))
}

/// Whether two integers share no common factor other than 1.
#[frb]
pub async fn number_coprime(
    first: String,
    second: String,
) -> Result<bool, SymbolicErrorInfo> {
    crate::symbolic::ntheory::coprime(&first, &second)
        .map_err(|e| SymbolicErrorInfo::from(&e))
}
