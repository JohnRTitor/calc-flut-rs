use symplex::prelude::{Context, Matrix};

use crate::shared::error::CommonError;
use crate::symbolic::error::SymbolicError;

/// Largest matrix accepted, in cells.
///
/// Every entry is held exactly, so the work grows with the number of terms
/// rather than the number of cells, but the elimination and factorisation
/// routines still take time that grows quickly. A limit is the only predictable
/// guard available before the work starts.
pub const MAX_CELLS: usize = 64;

/// A matrix of exact expressions, as the user entered it.
#[derive(Debug, Clone)]
pub struct MatrixSpec {
    /// The cells, row-major. Every row must be the same length.
    pub cells: Vec<Vec<String>>,
}

impl MatrixSpec {
    /// Builds a spec from rows of cell text.
    pub fn new(cells: Vec<Vec<String>>) -> Self {
        Self { cells }
    }
}

/// Everything worth knowing about a matrix, computed in one pass.
///
/// Modelled as a single response rather than one request per quantity, because
/// a user who types a matrix wants to see all of it at once — and because a
/// separate round trip per value would be six times the work for the same
/// answer.
#[derive(Debug, Clone)]
pub struct MatrixAnalysis {
    /// Row-major cells of the matrix as entered.
    pub cells: Vec<Vec<String>>,
    /// The determinant, when the matrix is square.
    pub determinant: Option<String>,
    /// The rank, always defined.
    pub rank: usize,
    /// The trace, when the matrix is square.
    pub trace: Option<String>,
    /// The inverse, row-major and flattened. See [MatrixAnalysis::columns].
    pub inverse: Option<Vec<String>>,
    /// The reduced row-echelon form, row-major and flattened.
    pub reduced: Vec<String>,
    /// The eigenvalues, when they could all be found.
    ///
    /// `None` means the eigenvalues could not be determined, which is not the
    /// same as there being none.
    pub eigenvalues: Option<Vec<String>>,
    /// One representative eigenvector per *distinct* eigenvalue.
    ///
    /// Keyed by its own eigenvalue rather than listed in step with
    /// [MatrixAnalysis::eigenvalues], because those two do not line up: the
    /// eigenvalues come back with multiplicity while the eigenvectors come back
    /// per distinct value. The identity matrix has two eigenvalues and one
    /// eigenspace, so pairing them by position would report the wrong vector
    /// against the wrong value.
    pub eigenvectors: Option<Vec<EigenEntry>>,
    /// How many columns the flattened matrices have.
    ///
    /// flutter_rust_bridge cannot encode a nested vector, so matrices cross the
    /// bridge as one flat row-major list. The width is carried alongside rather
    /// than inferred, because unlike the Cayley table there is no header row to
    /// count.
    pub columns: usize,

    /// Facts about the shape that explain any omissions above.
    pub details: Option<String>,
}

/// A representative eigenvector together with the eigenvalue it belongs to.
#[derive(Debug, Clone)]
pub struct EigenEntry {
    /// The eigenvalue this vector belongs to.
    pub eigenvalue: String,
    /// One vector from its eigenspace, as a single row.
    pub vector: Vec<String>,
    /// How many independent vectors the eigenspace actually has.
    ///
    /// Reported so a two-dimensional eigenspace is not mistaken for a
    /// one-dimensional one, since only one vector is shown.
    pub eigenspace_dimension: usize,
}

/// Checks the cells form a matrix and parses them.
///
/// A ragged grid is refused rather than padded: padding would invent entries the
/// user never typed and produce an answer to a different matrix.
fn build(spec: &MatrixSpec) -> Result<(Context, Matrix), SymbolicError> {
    if spec.cells.is_empty() || spec.cells.iter().all(|row| row.is_empty()) {
        return Err(SymbolicError::EmptyMatrix);
    }

    let width = spec.cells[0].len();
    if width == 0 {
        return Err(SymbolicError::EmptyMatrix);
    }
    if spec.cells.iter().any(|row| row.len() != width) {
        return Err(SymbolicError::RaggedMatrix { expected: width });
    }
    if spec.cells.len() * width > MAX_CELLS {
        return Err(SymbolicError::TooLarge(format!(
            "more than {MAX_CELLS} cells"
        )));
    }

    let ctx = Context::new();
    let mut rows = Vec::with_capacity(spec.cells.len());
    for row in &spec.cells {
        let mut parsed = Vec::with_capacity(width);
        for cell in row {
            let trimmed = cell.trim();
            if trimmed.is_empty() {
                return Err(SymbolicError::EmptyCell);
            }
            parsed.push(
                ctx.parse(trimmed).map_err(|e| {
                    SymbolicError::from(CommonError::InvalidExpression(e.to_string()))
                })?,
            );
        }
        rows.push(parsed);
    }

    let matrix = Matrix::new(rows)
        .map_err(|e| SymbolicError::from(CommonError::InvalidExpression(e.to_string())))?;
    Ok((ctx, matrix))
}

/// Renders a matrix back to one flat, row-major list of cells.
///
/// Flat because flutter_rust_bridge cannot encode a nested vector, which makes
/// the web build fail to compile. The width travels alongside as
/// [MatrixAnalysis::columns], so the shape is still recoverable.
fn render(matrix: &Matrix) -> Vec<String> {
    (0..matrix.nrows())
        .flat_map(|row| {
            matrix
                .row(row)
                .iter()
                .map(|entry| entry.to_string())
                .collect::<Vec<String>>()
        })
        .collect()
}

/// Analyses a matrix.
///
/// Every value is exact: a determinant of a 30-digit matrix comes back as a
/// 30-digit integer, not a float that has quietly lost its last digits.
pub fn analyse(spec: &MatrixSpec) -> Result<MatrixAnalysis, SymbolicError> {
    let (_, matrix) = build(spec)?;

    let square = matrix.is_square();
    let mut details_parts: Vec<String> = Vec::new();
    if !square {
        details_parts.push(format!(
            "This matrix is {}x{}, so it has no determinant or trace.",
            matrix.nrows(),
            matrix.ncols()
        ));
    }

    let determinant = if square {
        matrix.det().ok().map(|value| value.to_string())
    } else {
        None
    };

    let trace = if square {
        matrix.trace().ok().map(|value| value.to_string())
    } else {
        None
    };

    let rank = matrix.rank();

    // A singular matrix has no inverse. That is a fact about the matrix, not a
    // failure, so it is reported as its absence with an explanation rather than
    // as an error.
    let inverse = match matrix.inv() {
        Ok(inverse) => Some(render(&inverse)),
        Err(_) => {
            if square {
                details_parts.push("This matrix is singular, so it has no inverse.".to_string());
            }
            None
        }
    };

    let (reduced, _) = matrix.rref();
    let reduced = render(&reduced);

    // Eigenvalues need a square matrix and may not all be expressible in
    // closed form. Reporting "could not determine" as an empty list would read
    // as "there are none", so the two cases stay apart.
    let (eigenvalues, eigenvectors) = if square {
        match matrix.eigenvals() {
            Ok(values) => {
                // `eigenvects` returns one group per distinct eigenvalue, each
                // holding a basis. Only one basis vector per eigenvalue is
                // reported — a basis of matrices is three levels deep and cannot
                // cross the bridge — and a wider eigenspace is called out rather
                // than silently truncated.
                let mut wide_eigenspace = false;
                let vectors = matrix.eigenvects().ok().map(|groups| {
                    groups
                        .into_iter()
                        .filter_map(|(eigenvalue, dimension, mut bases)| {
                            if dimension > 1 {
                                wide_eigenspace = true;
                            }
                            // Any basis vector will do as a representative.
                            // A basis is held as a column — one row per
                            // component — so it is read down, not across.
                            let basis = bases.pop()?;
                            Some(EigenEntry {
                                eigenvalue: eigenvalue.to_string(),
                                vector: (0..basis.nrows())
                                    .flat_map(|row| {
                                        basis
                                            .row(row)
                                            .iter()
                                            .map(|entry| entry.to_string())
                                            .collect::<Vec<String>>()
                                    })
                                    .collect(),
                                eigenspace_dimension: dimension,
                            })
                        })
                        .collect::<Vec<EigenEntry>>()
                });
                if wide_eigenspace {
                    details_parts.push(
                        "Some eigenvalues have a higher-dimensional eigenspace; one \
                         representative vector is shown for each."
                            .to_string(),
                    );
                }
                (
                    Some(values.into_iter().map(|v| v.to_string()).collect()),
                    vectors,
                )
            }
            Err(_) => {
                details_parts
                    .push("The eigenvalues could not all be expressed in closed form.".to_string());
                (None, None)
            }
        }
    } else {
        (None, None)
    };

    let details = (!details_parts.is_empty()).then(|| details_parts.join(" "));

    Ok(MatrixAnalysis {
        cells: spec.cells.clone(),
        determinant,
        rank,
        trace,
        inverse,
        reduced,
        columns: matrix.ncols(),
        eigenvalues,
        eigenvectors,
        details,
    })
}
