//! Tests for the matrix subsystem.
//!
//! Expectations are exact. A determinant over a large integer coming back as a
//! float is the failure this file exists to catch, so every value is asserted
//! as an exact string.

#[cfg(test)]
mod tests {
    use crate::symbolic::error::{SymbolicError, SymbolicErrorKind};
    use crate::symbolic::matrix::{MAX_CELLS, MatrixSpec, analyse};

    fn spec(rows: Vec<Vec<&str>>) -> MatrixSpec {
        MatrixSpec::new(
            rows.into_iter()
                .map(|row| row.into_iter().map(str::to_string).collect())
                .collect(),
        )
    }

    fn analyse_rows(rows: Vec<Vec<&str>>) -> crate::symbolic::matrix::MatrixAnalysis {
        analyse(&spec(rows)).expect("should analyse")
    }

    // ---------- determinant ----------

    #[test]
    fn test_determinant_of_a_known_matrix() {
        let analysis = analyse_rows(vec![vec!["2", "-1"], vec!["1", "0"]]);
        assert_eq!(analysis.determinant.as_deref(), Some("1"));
    }

    #[test]
    fn test_determinant_of_the_identity_is_one() {
        for n in 1..=4 {
            let rows: Vec<Vec<String>> = (0..n)
                .map(|i| {
                    (0..n)
                        .map(|j| {
                            if i == j {
                                "1".to_string()
                            } else {
                                "0".to_string()
                            }
                        })
                        .collect()
                })
                .collect();
            let analysis = analyse(&MatrixSpec::new(rows)).unwrap();
            assert_eq!(
                analysis.determinant.as_deref(),
                Some("1"),
                "{n}x{n} identity"
            );
        }
    }

    #[test]
    fn test_determinant_stays_exact_over_large_integers() {
        // The point of the whole exercise: no float, no lost digits.
        let big = "123456789012345678901234567890";
        let analysis = analyse_rows(vec![vec![big, "0"], vec!["0", "1"]]);
        assert_eq!(analysis.determinant.as_deref(), Some(big));
    }

    #[test]
    fn test_determinant_handles_fractions_exactly() {
        let analysis = analyse_rows(vec![vec!["1/2", "0"], vec!["0", "1/3"]]);
        assert_eq!(analysis.determinant.as_deref(), Some("1/6"));
    }

    #[test]
    fn test_singular_matrix_has_determinant_zero_not_an_error() {
        // Zero is the answer, not a failure.
        let analysis = analyse_rows(vec![vec!["1", "2"], vec!["2", "4"]]);
        assert_eq!(analysis.determinant.as_deref(), Some("0"));
    }

    // ---------- rank ----------

    #[test]
    fn test_rank_of_a_full_rank_matrix() {
        let analysis = analyse_rows(vec![vec!["1", "2"], vec!["3", "4"]]);
        assert_eq!(analysis.rank, 2);
    }

    #[test]
    fn test_rank_of_a_singular_matrix_drops() {
        let analysis = analyse_rows(vec![vec!["1", "2"], vec!["2", "4"]]);
        assert_eq!(analysis.rank, 1);
    }

    #[test]
    fn test_rank_of_the_zero_matrix_is_zero() {
        let analysis = analyse_rows(vec![vec!["0", "0"], vec!["0", "0"]]);
        assert_eq!(analysis.rank, 0);
    }

    // ---------- inverse ----------

    #[test]
    fn test_inverse_of_a_known_matrix() {
        let analysis = analyse_rows(vec![vec!["2", "-1"], vec!["1", "0"]]);
        let inverse = analysis.inverse.expect("this matrix is invertible");
        assert_eq!(inverse, vec!["0", "1", "-1", "2"]);
    }

    #[test]
    fn test_flat_matrices_carry_their_width() {
        // Matrices cross the bridge as one flat row-major list, because the
        // bridge cannot encode a nested vector. The width travels alongside, so
        // the shape is still recoverable. This is a 2x3 and a 3x1, which a
        // square-only fixture would let through untested.
        let wide = analyse_rows(vec![vec!["1", "2", "3"], vec!["4", "5", "6"]]);
        assert_eq!(wide.columns, 3);
        assert_eq!(wide.reduced.len(), 2 * 3);

        let tall = analyse_rows(vec![vec!["1"], vec!["2"], vec!["3"]]);
        assert_eq!(tall.columns, 1);
        assert_eq!(tall.reduced.len(), 3 * tall.columns);
    }

    #[test]
    fn test_flattening_preserves_the_row_major_order() {
        // The cells are real numbers, not position labels, because these are
        // parsed as expressions: "r1c1" would just be the product r*c, and the
        // matrix would collapse. A non-square matrix is what catches a
        // column-major reading, since a square one has the same entries in the
        // same places either way round.
        let analysis = analyse_rows(vec![vec!["1", "2", "3"], vec!["4", "5", "6"]]);
        assert_eq!(analysis.columns, 3);
        assert_eq!(
            analysis.reduced,
            vec!["1", "0", "-1", "0", "1", "2"],
            "the first three entries must be the first row, not the first column",
        );
    }

    #[test]
    fn test_inverse_multiplying_out_gives_the_identity() {
        // Checked by multiplication rather than against a written-out answer, so
        // the test is about the maths and not about my arithmetic.
        let ctx = symplex::prelude::Context::new();
        let build = |rows: Vec<Vec<String>>| {
            symplex::prelude::Matrix::new(
                rows.iter()
                    .map(|row| row.iter().map(|c| ctx.parse(c).unwrap()).collect())
                    .collect(),
            )
            .unwrap()
        };
        let original = build(vec![
            vec!["4".into(), "7".into()],
            vec!["2".into(), "6".into()],
        ]);
        let analysis = analyse_rows(vec![vec!["4", "7"], vec!["2", "6"]]);
        // Flattened cells are put back into rows before being rebuilt, which is
        // exactly what the Dart side does, so the round trip is covered here.
        let inverse = build(
            analysis
                .inverse
                .unwrap()
                .chunks(analysis.columns)
                .map(|row| row.to_vec())
                .collect(),
        );
        let product = original.matmul(&inverse).unwrap();
        let shown: Vec<Vec<String>> = (0..product.nrows())
            .map(|r| product.row(r).iter().map(|e| e.to_string()).collect())
            .collect();
        assert_eq!(shown, vec![vec!["1", "0"], vec!["0", "1"]]);
    }

    #[test]
    fn test_singular_matrix_reports_no_inverse_with_a_reason() {
        // Absence, not failure: a singular matrix genuinely has no inverse.
        let analysis = analyse_rows(vec![vec!["1", "2"], vec!["2", "4"]]);
        assert!(analysis.inverse.is_none());
        let details = analysis.details.expect("the absence must be explained");
        assert!(details.contains("singular"), "got: {details}");
    }

    // ---------- trace and eigenvalues ----------

    #[test]
    fn test_trace_of_a_diagonal_matrix_is_the_diagonal_sum() {
        let analysis = analyse_rows(vec![vec!["2", "0"], vec!["0", "3"]]);
        assert_eq!(analysis.trace.as_deref(), Some("5"));
    }

    #[test]
    fn test_eigenvalues_of_a_diagonal_matrix_are_its_diagonal() {
        let analysis = analyse_rows(vec![
            vec!["2", "0", "0"],
            vec!["0", "3", "0"],
            vec!["0", "0", "4"],
        ]);
        let mut values = analysis.eigenvalues.expect("should be determinable");
        values.sort();
        assert_eq!(values, vec!["2", "3", "4"]);
    }

    #[test]
    fn test_eigenvalues_of_a_symmetric_pair_come_out_exactly() {
        // [[2,1],[1,2]] has eigenvalues 1 and 3.
        let analysis = analyse_rows(vec![vec!["2", "1"], vec!["1", "2"]]);
        let mut values = analysis.eigenvalues.expect("should be determinable");
        values.sort();
        assert_eq!(values, vec!["1", "3"]);
    }

    #[test]
    fn test_each_eigenvector_is_labelled_with_its_own_eigenvalue() {
        // Not paired by position: the eigenvalues come back with multiplicity
        // and the eigenvectors per distinct value, so the two do not line up and
        // a positional pairing would name the wrong vector.
        let analysis = analyse_rows(vec![vec!["2", "1"], vec!["1", "2"]]);
        let entries = analysis.eigenvectors.expect("should be determinable");
        assert_eq!(entries.len(), 2);
        let mut pairs: Vec<(String, String)> = entries
            .iter()
            .map(|entry| (entry.eigenvalue.clone(), entry.vector.join(",")))
            .collect();
        pairs.sort();
        assert_eq!(
            pairs,
            vec![
                ("1".to_string(), "-1,1".to_string()),
                ("3".to_string(), "1,1".to_string()),
            ]
        );
    }

    #[test]
    fn test_a_repeated_eigenvalue_is_not_double_counted() {
        // The identity has two eigenvalues but one eigenspace. Reporting two
        // vectors would invent an answer, and reporting one per eigenvalue
        // occurrence would repeat the same one.
        let analysis = analyse_rows(vec![vec!["1", "0"], vec!["0", "1"]]);
        assert_eq!(analysis.eigenvalues.unwrap(), vec!["1", "1"]);
        let entries = analysis.eigenvectors.expect("should be determinable");
        assert_eq!(entries.len(), 1);
        assert_eq!(entries[0].eigenvalue, "1");
        assert_eq!(entries[0].eigenspace_dimension, 2);
        // The wider eigenspace is reported rather than silently truncated.
        let details = analysis.details.expect("the truncation must be stated");
        assert!(details.contains("higher-dimensional"), "got: {details}");
    }

    #[test]
    fn test_eigenvectors_are_one_row_each() {
        let analysis = analyse_rows(vec![vec!["2", "1"], vec!["1", "2"]]);
        for entry in analysis.eigenvectors.expect("should be determinable") {
            assert_eq!(entry.vector.len(), 2);
        }
    }

    // ---------- shape handling ----------

    #[test]
    fn test_a_non_square_matrix_has_no_determinant_or_eigenvalues() {
        let analysis = analyse_rows(vec![vec!["1", "2", "3"], vec!["4", "5", "6"]]);
        assert!(analysis.determinant.is_none());
        assert!(analysis.trace.is_none());
        assert!(analysis.eigenvalues.is_none());
        // But the things that do exist still do.
        assert_eq!(analysis.rank, 2);
        assert!(!analysis.reduced.is_empty());
        let details = analysis.details.expect("the omissions must be explained");
        assert!(details.contains("2x3"), "got: {details}");
    }

    // ---------- input errors ----------

    #[test]
    fn test_an_empty_grid_is_refused() {
        let error = analyse(&MatrixSpec::new(vec![])).unwrap_err();
        assert!(matches!(error, SymbolicError::EmptyMatrix));
        assert_eq!(error.kind(), SymbolicErrorKind::Unsupported);
    }

    #[test]
    fn test_a_ragged_grid_is_refused_rather_than_padded() {
        // Padding would invent entries the user never typed and answer a
        // different question.
        let error = analyse(&spec(vec![vec!["1", "2"], vec!["3"]])).unwrap_err();
        assert!(matches!(error, SymbolicError::RaggedMatrix { expected: 2 }));
    }

    #[test]
    fn test_a_blank_cell_is_refused_rather_than_read_as_zero() {
        let error = analyse(&spec(vec![vec!["1", " "], vec!["3", "4"]])).unwrap_err();
        assert!(matches!(error, SymbolicError::EmptyCell));
    }

    #[test]
    fn test_an_unparseable_cell_names_the_input_error_kind() {
        let error = analyse(&spec(vec![vec!["1", "x^^"], vec!["3", "4"]])).unwrap_err();
        assert_eq!(error.kind(), SymbolicErrorKind::Input);
    }

    #[test]
    fn test_oversized_grids_are_refused() {
        let n = MAX_CELLS + 1;
        let rows: Vec<Vec<String>> = (0..n).map(|_| vec!["1".to_string()]).collect();
        let error = analyse(&MatrixSpec::new(rows)).unwrap_err();
        assert!(matches!(error, SymbolicError::TooLarge(_)));
    }

    #[test]
    fn test_the_grid_is_echoed_back_exactly() {
        let analysis = analyse_rows(vec![vec!["1/2", "2"], vec!["3", "4"]]);
        assert_eq!(analysis.cells, vec![vec!["1/2", "2"], vec!["3", "4"]]);
    }
}
