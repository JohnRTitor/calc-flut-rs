//! Tests for curve plotting.
//!
//! The thing worth testing is not that sampling produces numbers — it is that
//! holes in a curve stay holes. Plotting a line through an asymptote, or across
//! a domain boundary, shows a function that does not exist, and that is the
//! failure mode a plot has that an expression does not.

#[cfg(test)]
mod tests {
    use crate::symbolic::error::{SymbolicError, SymbolicErrorKind};
    use crate::symbolic::plot::{DEFAULT_WINDOW, PlotCurve, plot};

    /// Plots `expression` and returns `(points, y_range)`.
    fn curve(expression: &str) -> (Vec<Option<f64>>, (f64, f64)) {
        let data = plot(expression, Some("x"), 200).expect("should plot");
        (
            data.points.iter().map(|point| point.y).collect(),
            (data.y_min, data.y_max),
        )
    }

    /// The sample nearest `x`, for checking particular values.
    ///
    /// The samples are spaced across the window and need not land on round
    /// numbers, so this finds the closest one rather than computing an index.
    fn y_near(data: &PlotCurve, x: f64) -> Option<f64> {
        data.points
            .iter()
            .min_by(|a, b| {
                (a.x - x)
                    .abs()
                    .partial_cmp(&(b.x - x).abs())
                    .unwrap_or(std::cmp::Ordering::Equal)
            })
            .and_then(|point| point.y)
    }

    /// The horizontal distance between neighbouring samples.
    fn step(data: &PlotCurve) -> f64 {
        (data.x_max - data.x_min) / (data.points.len() as f64 - 1.0)
    }

    /// The most the sampled value can differ from the true one at `sample_at`.
    ///
    /// Samples do not land on round numbers, so a check has to allow for where
    /// the nearest sample actually fell. The first term is the local slope times
    /// the spacing, which is the first-order error. The second covers the
    /// second-order error that remains where the slope passes through zero, as
    /// it does for `x^2` at the origin, and is a small fraction of the curve's
    /// own height so it stays a check rather than a rubber stamp.
    fn tolerance_for(data: &PlotCurve, local_slope: f64) -> f64 {
        let span = data.y_max - data.y_min;
        local_slope.abs() * step(data) + span.abs() * 1e-3 + 1e-9
    }

    // ---------- shape ----------

    #[test]
    fn test_a_parabola_matches_its_known_values() {
        let data = plot("x^2", Some("x"), 200).unwrap();
        // x^2 has slope 2x.
        assert!(y_near(&data, 0.0).unwrap().abs() < tolerance_for(&data, 0.0));
        assert!((y_near(&data, 2.0).unwrap() - 4.0).abs() < tolerance_for(&data, 4.0));
        assert!((y_near(&data, -3.0).unwrap() - 9.0).abs() < tolerance_for(&data, 6.0));
    }

    #[test]
    fn test_a_sine_wave_oscillates_rather_than_growing() {
        let data = plot("sin(x)", Some("x"), 400).unwrap();
        // cos(x) is at most 1 in absolute value, so the slope bounds the error.
        assert!(y_near(&data, 0.0).unwrap().abs() < tolerance_for(&data, 1.0));
        let peak = y_near(&data, std::f64::consts::FRAC_PI_2).unwrap();
        assert!((peak - 1.0).abs() < tolerance_for(&data, 1.0));
        // Bounded, so the vertical axis is bounded too.
        assert!(data.y_max < 2.0);
    }

    #[test]
    fn test_the_window_is_the_documented_default() {
        let data = plot("x", Some("x"), 100).unwrap();
        assert_eq!(data.x_min, DEFAULT_WINDOW.0);
        assert_eq!(data.x_max, DEFAULT_WINDOW.1);
        assert!(data.points.len() >= 100);
    }

    #[test]
    fn test_samples_run_strictly_left_to_right() {
        let data = plot("x^2", Some("x"), 150).unwrap();
        for pair in data.points.windows(2) {
            assert!(pair[1].x > pair[0].x, "samples must increase in x");
        }
    }

    // ---------- gaps ----------

    #[test]
    fn test_a_pole_is_a_gap_not_an_infinity() {
        // 1/x is infinite at zero. Plotting that point would stretch the axis
        // to nothing; the curve should simply have a hole there.
        let (points, _) = curve("1/x");
        assert!(
            points.contains(&None),
            "1/x must have at least one gap"
        );
        let data = plot("1/x", Some("x"), 200).unwrap();
        assert!(y_near(&data, 2.0).is_some(), "1/x is defined at 2");
    }

    #[test]
    fn test_a_pole_does_not_get_a_line_thrown_across_it() {
        // The samples either side of zero are ordinary finite values, so
        // without a discontinuity check the chart would draw a straight line
        // through the asymptote and appear to say 1/x is continuous there.
        let data = plot("1/x", Some("x"), 200).unwrap();
        let step = step(&data);
        let zero_index = data
            .points
            .iter()
            .position(|point| point.x.abs() < step / 2.0)
            .expect("a sample at zero");

        // A window of samples centred on the pole must contain a gap.
        let from = zero_index.saturating_sub(5);
        let to = (zero_index + 5).min(data.points.len() - 1);
        assert!(
            data.points[from..=to].iter().any(|point| point.y.is_none()),
            "a line would be drawn straight through the pole at x = 0"
        );
    }

    #[test]
    fn test_a_domain_edge_is_a_gap() {
        // sqrt(x) is undefined for negative x.
        let (points, _) = curve("sqrt(x)");
        assert!(points.contains(&None), "sqrt(x) has no negative side");
        let data = plot("sqrt(x)", Some("x"), 200).unwrap();
        assert!(y_near(&data, 4.0).is_some());
    }

    #[test]
    fn test_a_logarithm_has_no_non_positive_side() {
        let (points, _) = curve("ln(x)");
        assert!(points.contains(&None));
        let data = plot("ln(x)", Some("x"), 200).unwrap();
        let value = y_near(&data, std::f64::consts::E).unwrap();
        assert!((value - 1.0).abs() < 0.05);
    }

    #[test]
    fn test_a_steep_but_continuous_curve_is_not_broken() {
        // exp(x) climbs by four orders of magnitude across the window, but it
        // is continuous and never changes sign. A check that keyed off the size
        // of the step would have broken this curve, hiding its real shape.
        let (points, _) = curve("exp(x)");
        assert!(
            !points.contains(&None),
            "exp(x) is continuous and should have no gaps"
        );
    }

    #[test]
    fn test_a_zero_crossing_is_not_mistaken_for_a_pole() {
        // x^2 - 4 crosses zero at x = 2, and does so through small values.
        // That is a crossing, not a pole, so the curve must stay whole.
        let (points, _) = curve("x^2-4");
        assert!(
            !points.contains(&None),
            "a zero crossing should not be cut as if it were an asymptote"
        );
    }

    #[test]
    fn test_a_poly_cubed_pole_is_still_broken() {
        // 1/x^3 diverges far harder than 1/x, and must be caught too.
        let (points, _) = curve("1/x^3");
        assert!(points.contains(&None));
    }

    #[test]
    fn test_a_tangent_pole_is_broken() {
        let (points, _) = curve("tan(x)");
        assert!(points.contains(&None), "tan has poles at pi/2 and -pi/2");
    }

    // ---------- vertical range ----------

    #[test]
    fn test_the_range_brackets_the_curve_with_room_to_spare() {
        let (_, (y_min, y_max)) = curve("x^2");
        // Over [-10, 10] the parabola reaches 100.
        assert!(y_min < 0.0, "should sit below the lowest point");
        assert!(y_max > 100.0, "should sit above the highest point");
    }

    #[test]
    fn test_a_constant_curve_gets_a_band_rather_than_a_flat_line() {
        // Otherwise the line lands exactly on the axis and reads as an axis.
        let (_, (y_min, y_max)) = curve("5");
        assert!(y_min < 5.0 && y_max > 5.0);
    }

    #[test]
    fn test_a_value_beyond_the_ceiling_is_treated_as_out_of_range() {
        // Without a ceiling one sample near a pole flattens everything else.
        let (_, (_, y_max)) = curve("1/x^2");
        assert!(
            y_max < 1e12,
            "a near-pole sample must not stretch the axis to {}",
            y_max
        );
    }

    // ---------- what cannot be plotted ----------

    #[test]
    fn test_a_curve_needs_a_variable() {
        let error = plot("x^2", None, 100).unwrap_err();
        assert!(matches!(error, SymbolicError::NoVariable));
    }

    #[test]
    fn test_two_variables_cannot_be_drawn_on_one_pair_of_axes() {
        // Silently holding y at some value would show a curve the user never
        // asked for.
        let error = plot("x^2 + y", Some("x"), 100).unwrap_err();
        assert!(matches!(error, SymbolicError::NotSupported(_)));
        assert_eq!(error.kind(), SymbolicErrorKind::Unsupported);
    }

    #[test]
    fn test_plotting_by_the_wrong_symbol_is_refused() {
        // Asking for the curve in `y` when the expression is in `x` is a
        // different question, not one to answer with a default.
        let error = plot("x^2", Some("y"), 100).unwrap_err();
        assert!(matches!(error, SymbolicError::NotSupported(_)));
    }

    #[test]
    fn test_empty_and_oversized_input() {
        assert!(matches!(
            plot("  ", Some("x"), 100).unwrap_err(),
            SymbolicError::EmptyExpression
        ));
        let huge = "x".repeat(crate::symbolic::MAX_EXPRESSION_CHARS + 1);
        assert!(matches!(
            plot(&huge, Some("x"), 100).unwrap_err(),
            SymbolicError::TooLarge(_)
        ));
    }

    #[test]
    fn test_silly_sample_counts_are_clamped_rather_than_obeyed() {
        // One sample cannot describe a curve, and an enormous count would let
        // the caller ask for unbounded work.
        assert!(plot("x", Some("x"), 0).unwrap().points.len() >= 2);
        assert!(plot("x", Some("x"), 1).unwrap().points.len() >= 2);
        assert!(plot("x", Some("x"), 100_000).unwrap().points.len() <= 2000);
    }

    #[test]
    fn test_invalid_syntax_is_an_input_error() {
        let error = plot("x^^2", Some("x"), 100).unwrap_err();
        assert_eq!(error.kind(), SymbolicErrorKind::Input);
    }
}
