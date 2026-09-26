use symplex::prelude::Context;

use crate::shared::error::CommonError;
use crate::symbolic::error::SymbolicError;
use crate::symbolic::evaluator::MAX_EXPRESSION_CHARS;

/// Number of samples taken across the window.
///
/// Enough that a curve reads as a curve on a phone, few enough that the work
/// stays trivially cheap.
pub const DEFAULT_SAMPLES: u32 = 240;

/// The default view, used when the user has not panned or zoomed.
///
/// Deliberately not chosen by inspecting the expression: picking a "good"
/// window means spending symbolic effort before the chart can show anything at
/// all, and a window the user did not ask for is a surprise. A round, obviously
/// arbitrary default is easier to reason about and to change.
pub const DEFAULT_WINDOW: (f64, f64) = (-10.0, 10.0);

/// A y-value this large is treated as out of range rather than plotted.
///
/// Without it a single sample near a pole (or a function that grows like `e^x`)
/// flattens every other part of the curve against the axis.
const Y_CEILING: f64 = 1e12;

/// A sampled point on the curve.
///
/// `y` is `None` where the function is undefined, which is a hole in the curve
/// rather than a value of zero. Plotting through it would draw a line across an
/// asymptote and show a function that is not there.
///
/// Named apart from the bridge's `PlotPoint` on purpose: flutter_rust_bridge
/// keys generated objects by name, and two public types sharing one name make
/// it pick arbitrarily between them.
#[derive(Debug, Clone, Copy)]
pub struct PlotSample {
    /// The abscissa.
    pub x: f64,
    /// The ordinate, or `None` where the function is undefined.
    pub y: Option<f64>,
}

/// A sampled curve and the window it was taken over.
///
/// Named apart from the bridge's `PlotData` on purpose: flutter_rust_bridge
/// keys generated objects by name, and two public types sharing one name make
/// it pick arbitrarily between them.
#[derive(Debug, Clone)]
pub struct PlotCurve {
    /// The samples, in increasing `x`.
    pub points: Vec<PlotSample>,
    /// Lower bound of the sampled window.
    pub x_min: f64,
    /// Upper bound of the sampled window.
    pub x_max: f64,
    /// Smallest plotted ordinate, for setting the vertical axis.
    pub y_min: f64,
    /// Largest plotted ordinate, for setting the vertical axis.
    pub y_max: f64,
}

/// Samples `expression` numerically across a window.
///
/// Plotting needs values, not algebra, so the expression is compiled once into
/// a function and evaluated per sample rather than being symbolically
/// transformed. A point the function cannot produce — a division by zero, the
/// square root of a negative number — becomes a gap.
pub fn plot(
    expression: &str,
    variable: Option<&str>,
    samples: u32,
) -> Result<PlotCurve, SymbolicError> {
    let trimmed = expression.trim();
    if trimmed.is_empty() {
        return Err(SymbolicError::EmptyExpression);
    }
    if trimmed.chars().count() > MAX_EXPRESSION_CHARS {
        return Err(SymbolicError::TooLarge(format!(
            "over {} characters",
            MAX_EXPRESSION_CHARS
        )));
    }

    let variable = variable
        .map(str::trim)
        .filter(|name| !name.is_empty())
        .ok_or(SymbolicError::NoVariable)?;

    let ctx = Context::new();
    let parsed = ctx
        .parse(trimmed)
        .map_err(|e| SymbolicError::from(CommonError::InvalidExpression(e.to_string())))?;

    let target = ctx.try_symbol(variable).map_err(|_| {
        SymbolicError::InvalidExpression(format!(
            "'{}' is not a usable variable name",
            variable
        ))
    })?;

    // A curve needs one pair of axes. An expression in two variables cannot be
    // drawn on them, and a free symbol other than the chosen variable would
    // silently be held at some arbitrary value while the user believed it was
    // being drawn. A constant is fine: it draws a horizontal line.
    let free = parsed.free_symbols();
    let only_the_target = free.iter().all(|symbol| *symbol == target);
    if !free.is_empty() && !only_the_target {
        return Err(SymbolicError::NotSupported(
            "only an expression in one variable can be plotted".to_string(),
        ));
    }

    let compiled = parsed
        .compile(&[variable])
        .map_err(|e| SymbolicError::from(CommonError::InvalidExpression(e.to_string())))?;

    let sample_count = samples.clamp(2, 2000);
    let (x_min, x_max) = DEFAULT_WINDOW;
    let step = (x_max - x_min) / f64::from(sample_count - 1);

    let mut points = Vec::with_capacity(sample_count as usize);
    for index in 0..sample_count {
        let x = x_min + step * f64::from(index);
        let y = compiled(&[x]);
        let y = if y.is_finite() && y.abs() < Y_CEILING {
            Some(y)
        } else {
            None
        };
        points.push(PlotSample { x, y });
    }

    let points = break_at_asymptotes(points);

    let (y_min, y_max) = vertical_range(&points);

    Ok(PlotCurve {
        points,
        x_min,
        x_max,
        y_min,
        y_max,
    })
}

/// The vertical extent of the curve, padded so it does not touch the axes.
fn vertical_range(points: &[PlotSample]) -> (f64, f64) {
    let mut lowest = f64::INFINITY;
    let mut highest = f64::NEG_INFINITY;
    for point in points {
        let Some(y) = point.y else { continue };
        lowest = lowest.min(y);
        highest = highest.max(y);
    }

    if !lowest.is_finite() || !highest.is_finite() {
        // Nothing plottable at all; the caller reports that separately.
        return (-1.0, 1.0);
    }

    let span = highest - lowest;
    if span <= 0.0 {
        // A constant function has no height; give it a band so the line lands
        // in the middle of the view instead of on the axis.
        return (lowest - 1.0, highest + 1.0);
    }
    let pad = span * 0.1;
    (lowest - pad, highest + pad)
}

/// How many times the curve's typical magnitude a sign change must exceed
/// before it counts as a pole rather than an ordinary zero crossing.
const POLE_MAGNITUDE_FACTOR: f64 = 8.0;

/// Turns a jump across a pole into a gap.
///
/// `1/x` is finite on both sides of zero and infinite at it, so the samples
/// either side of the pole look like ordinary points. Connecting them would
/// draw a line straight through the asymptote, showing a function that does not
/// exist.
///
/// What marks a pole is a sign change that stays *large*. A curve crossing zero
/// passes through small values on the way (`x^2 - 4` at `x = 2`), whereas either
/// side of a pole the magnitude stays big. The yardstick is the curve's median
/// magnitude rather than its maximum, because a single extreme sample
/// elsewhere in the window would otherwise raise the bar so high that a real
/// pole went unnoticed — which is exactly what happens with `tan(x)`, whose
/// spikes set the maximum while its typical value stays near 1.
fn break_at_asymptotes(mut points: Vec<PlotSample>) -> Vec<PlotSample> {
    let mut magnitudes: Vec<f64> = points
        .iter()
        .filter_map(|point| point.y.map(f64::abs))
        .filter(|magnitude| magnitude.is_finite() && *magnitude > 0.0)
        .collect();

    if magnitudes.is_empty() {
        return points;
    }
    magnitudes.sort_by(|a, b| a.partial_cmp(b).unwrap_or(std::cmp::Ordering::Equal));
    let typical = magnitudes[magnitudes.len() / 2];
    if !typical.is_finite() || typical <= 0.0 {
        // Degenerate: the curve is zero almost everywhere, so there is no
        // scale to judge a pole against. Leave it alone.
        return points;
    }
    let threshold = typical * POLE_MAGNITUDE_FACTOR;

    for index in 1..points.len() {
        let (Some(a), Some(b)) = (points[index - 1].y, points[index].y) else {
            continue;
        };
        if a.is_sign_negative() == b.is_sign_negative() {
            continue;
        }
        if a.abs() > threshold && b.abs() > threshold {
            // Drop the point on the far side of the jump, opening a gap wide
            // enough that no line can be drawn across it.
            points[index].y = None;
        }
    }

    points
}
