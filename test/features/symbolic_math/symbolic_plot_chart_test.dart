import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:calc_flut_rs/app/theme/app_theme.dart';
import 'package:calc_flut_rs/app/theme/ui_style.dart';
import 'package:calc_flut_rs/features/settings/presentation/providers/theme_provider.dart';
import 'package:calc_flut_rs/features/symbolic_math/presentation/widgets/symbolic_plot_chart.dart';
import 'package:calc_flut_rs/generated/rust/bridge/symbolic.dart' as rust_symbolic;

rust_symbolic.PlotPoint _point(double x, double? y) =>
    rust_symbolic.PlotPoint(x: x, y: y);

rust_symbolic.PlotData _data(
  List<rust_symbolic.PlotPoint> points, {
  double yMin = -1,
  double yMax = 1,
}) {
  return rust_symbolic.PlotData(
    points: points,
    xMin: -10,
    xMax: 10,
    yMin: yMin,
    yMax: yMax,
  );
}

Widget _host(UiStyle uiStyle, rust_symbolic.PlotData data) {
  return MaterialApp(
    theme: AppTheme.lightTheme(null, uiStyle, AppColorOption.defaultColor),
    home: Scaffold(
      body: SizedBox(width: 400, height: 300, child: SymbolicPlotChart(data: data)),
    ),
  );
}

void main() {
  group('splitIntoRuns', () {
    test('a continuous curve is one run', () {
      final runs = splitIntoRuns([
        _point(0, 0),
        _point(1, 1),
        _point(2, 4),
      ]);
      expect(runs, hasLength(1));
      expect(runs.first, hasLength(3));
    });

    test('a hole splits the curve in two', () {
      final runs = splitIntoRuns([
        _point(-1, -2),
        _point(0, null),
        _point(1, 2),
      ]);
      expect(runs, hasLength(2));
      expect(runs.first.single.y, -2);
      expect(runs.last.single.y, 2);
    });

    test('two holes make three runs', () {
      final runs = splitIntoRuns([
        _point(0, 1),
        _point(1, null),
        _point(2, 2),
        _point(3, null),
        _point(4, 4),
      ]);
      expect(runs, hasLength(3));
    });

    test('a curve that is undefined throughout has no runs', () {
      final runs = splitIntoRuns([_point(0, null), _point(1, null)]);
      expect(runs, isEmpty);
    });

    test('a leading or trailing hole does not create an empty run', () {
      final runs = splitIntoRuns([_point(0, null), _point(1, 5)]);
      expect(runs, hasLength(1));
      expect(runs.first.single.y, 5);
    });

    test('consecutive holes collapse into one break', () {
      final runs = splitIntoRuns([
        _point(0, 1),
        _point(1, null),
        _point(2, null),
        _point(3, 2),
      ]);
      expect(runs, hasLength(2));
    });
  });

  group('SymbolicPlotChart', () {
    for (final uiStyle in UiStyle.values) {
      testWidgets('renders a continuous curve as one unbroken line ($uiStyle)', (
        tester,
      ) async {
        await tester.pumpWidget(
          _host(
            uiStyle,
            _data([
              for (var i = 0; i <= 10; i++) _point(i.toDouble(), (i * i).toDouble()),
            ], yMax: 110),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);

        final chart = tester.widget<LineChart>(find.byType(LineChart));
        final spots = chart.data.lineBarsData.first.spots;
        // No separator, because there is no gap to separate.
        expect(spots.where((spot) => spot.isNull()).length, 0);
        expect(spots.length, 11);
      });

      testWidgets('breaks the line at a hole rather than joining across it ($uiStyle)',
          (tester) async {
        // Joining across a pole would draw a straight line through the
        // asymptote and show a function that does not exist there.
        await tester.pumpWidget(
          _host(
            uiStyle,
            _data([
              _point(-2, -0.5),
              _point(-1, -1),
              _point(0, null),
              _point(1, 1),
              _point(2, 0.5),
            ], yMin: -1.5, yMax: 1.5),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);

        final chart = tester.widget<LineChart>(find.byType(LineChart));
        final spots = chart.data.lineBarsData.first.spots;
        expect(
          spots.where((spot) => spot.isNull()).length,
          1,
          reason: 'two runs need exactly one separator',
        );
      });

      testWidgets('says so when the function has no values to show ($uiStyle)', (
        tester,
      ) async {
        await tester.pumpWidget(
          _host(uiStyle, _data([_point(0, null), _point(1, null)])),
        );
        await tester.pumpAndSettle();

        expect(find.byType(LineChart), findsNothing);
        expect(
          find.textContaining('no values'),
          findsOneWidget,
        );
      });

      testWidgets('uses the sampled window for both axes ($uiStyle)', (
        tester,
      ) async {
        await tester.pumpWidget(
          _host(
            uiStyle,
            _data([_point(-10, -1), _point(0, 0), _point(10, 1)], yMin: -2, yMax: 2),
          ),
        );
        await tester.pumpAndSettle();

        final chart = tester.widget<LineChart>(find.byType(LineChart));
        expect(chart.data.minX, -10);
        expect(chart.data.maxX, 10);
        expect(chart.data.minY, -2);
        expect(chart.data.maxY, 2);
      });

      testWidgets('labels both axes ($uiStyle)', (tester) async {
        await tester.pumpWidget(
          _host(
            uiStyle,
            _data([_point(-5, -1), _point(0, 0), _point(5, 1)], yMin: -2, yMax: 2),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(SideTitleWidget), findsWidgets);
      });
    }

    test('a very large span does not produce a zero gridline interval', () {
      // A degenerate interval would make the chart divide by zero or draw an
      // unreadable number of lines.
      final data = _data([_point(0, -1e9), _point(1, 1e9)], yMin: -1e9, yMax: 1e9);
      expect(data.yMax - data.yMin, isPositive);
    });
  });
}
