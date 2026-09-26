import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:calc_flut_rs/generated/rust/bridge/symbolic.dart' as rust_symbolic;

/// Splits sampled points into the runs that can be joined by a line.
///
/// A `None` y is a hole in the curve — a pole, or the edge of a domain — and a
/// line drawn through it would show a function that does not exist. Each run is
/// one continuous piece; a gap between runs is real.
List<List<rust_symbolic.PlotPoint>> splitIntoRuns(
  List<rust_symbolic.PlotPoint> points,
) {
  final runs = <List<rust_symbolic.PlotPoint>>[];
  var current = <rust_symbolic.PlotPoint>[];

  for (final point in points) {
    if (point.y == null) {
      if (current.isNotEmpty) runs.add(current);
      current = <rust_symbolic.PlotPoint>[];
      continue;
    }
    current.add(point);
  }
  if (current.isNotEmpty) runs.add(current);
  return runs;
}

/// A line chart of a sampled curve.
///
/// Gaps are drawn as separate runs separated by a null spot, which is how
/// `fl_chart` expects a line to be broken: connecting across a hole would draw
/// a straight line through an asymptote and imply a value the function does not
/// take.
class SymbolicPlotChart extends StatelessWidget {
  final rust_symbolic.PlotData data;

  const SymbolicPlotChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final runs = splitIntoRuns(data.points);

    if (runs.isEmpty) {
      return Center(
        child: Text(
          'This function has no values in the visible range',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    return LineChart(
      LineChartData(
        minX: data.xMin,
        maxX: data.xMax,
        minY: data.yMin,
        maxY: data.yMax,
        lineBarsData: [
          LineChartBarData(
            spots: _spotsFor(runs),
            isCurved: false,
            color: colorScheme.primary,
            barWidth: 2.5,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: colorScheme.primary.withValues(alpha: 0.10),
            ),
          ),
        ],
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          horizontalInterval: _interval(data.yMax - data.yMin),
          verticalInterval: _interval(data.xMax - data.xMin),
          getDrawingHorizontalLine: (_) => FlLine(
            color: colorScheme.outlineVariant.withValues(alpha: 0.4),
            strokeWidth: 1,
          ),
          getDrawingVerticalLine: (_) => FlLine(
            color: colorScheme.outlineVariant.withValues(alpha: 0.25),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              interval: _interval(data.yMax - data.yMin),
              getTitlesWidget: (value, meta) => SideTitleWidget(
                meta: meta,
                child: Text(
                  _formatTick(value),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: _interval(data.xMax - data.xMin),
              getTitlesWidget: (value, meta) => SideTitleWidget(
                meta: meta,
                child: Text(
                  _formatTick(value),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      duration: const Duration(milliseconds: 250),
    );
  }

  /// The runs as one spot list, with a null spot between them.
  static List<FlSpot> _spotsFor(List<List<rust_symbolic.PlotPoint>> runs) {
    final spots = <FlSpot>[];
    for (var index = 0; index < runs.length; index++) {
      if (index > 0) {
        // The separator goes at the first x of the run that follows, so the two
        // segments are not joined by it.
        spots.add(FlSpot.nullSpot);
      }
      for (final point in runs[index]) {
        final y = point.y;
        if (y == null) continue;
        spots.add(FlSpot(point.x, y));
      }
    }
    return spots;
  }

  /// A round interval giving a readable number of gridlines.
  static double _interval(double span) {
    if (!span.isFinite || span <= 0) return 1;
    final rough = span / 5;
    final magnitude = _pow10(rough.abs());
    final normalised = rough / magnitude;
    final step = normalised <= 1
        ? 1.0
        : normalised <= 2
        ? 2.0
        : normalised <= 5
        ? 5.0
        : 10.0;
    return step * magnitude;
  }

  static double _pow10(double value) {
    var magnitude = 1.0;
    while (value >= 10) {
      value /= 10;
      magnitude *= 10;
    }
    while (value < 1) {
      value *= 10;
      magnitude /= 10;
    }
    return magnitude;
  }

  /// Formats an axis label without a long tail of decimals.
  static String _formatTick(double value) {
    if (value == 0) return '0';
    if (value.abs() >= 1e6 || value.abs() < 1e-4) {
      return value.toStringAsExponential(1);
    }
    final rounded = value.roundToDouble();
    if ((value - rounded).abs() < 1e-9) return rounded.toStringAsFixed(0);
    return value.toStringAsFixed(2);
  }
}
