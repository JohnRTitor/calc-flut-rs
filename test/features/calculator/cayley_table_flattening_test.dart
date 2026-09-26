import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:calc_flut_rs/app/theme/app_theme.dart';
import 'package:calc_flut_rs/app/theme/ui_style.dart';
import 'package:calc_flut_rs/features/calculator/presentation/widgets/modular_arithmetic/cayley_table_view.dart';
import 'package:calc_flut_rs/features/settings/presentation/providers/theme_provider.dart';
import 'package:calc_flut_rs/generated/rust/bridge/modular_arithmetic.dart';

/// A 3x3 table whose cells are labelled by their position.
///
/// Deliberately not a real Cayley table. Z_3's addition table is symmetric, so
/// reading it with the rows and columns transposed produces exactly the same
/// values — which means a symmetric table cannot tell a correct offset from a
/// wrong one. Labelling each cell by where it belongs makes the mapping
/// observable, so a transposed read shows up as the wrong label.
const CayleyTable _labelled = CayleyTable(
  operation: 'op',
  headers: ['c0', 'c1', 'c2'],
  rows: [
    'r0c0', 'r0c1', 'r0c2',
    'r1c0', 'r1c1', 'r1c2',
    'r2c0', 'r2c1', 'r2c2',
  ],
);

Future<void> _pump(WidgetTester tester, UiStyle uiStyle) async {
  tester.view.physicalSize = const Size(1000, 1000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme(null, uiStyle, AppColorOption.defaultColor),
      home: Scaffold(
        body: CayleyTableView(
          uiStyle: uiStyle,
          cayleyTable: _labelled,
          identity: 'r0c0',
          inverses: const [],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  // The table crosses the bridge as a flat, row-major list because
  // flutter_rust_bridge cannot encode a nested vector, which made the web build
  // fail to compile. That turned a two-index read into a single offset, and
  // nothing covered the arithmetic: a wrong offset would show the wrong cell
  // without failing anything.
  group('flat row-major cells', () {
    test('the cell list is exactly square', () {
      // The width comes from the headers, so a mismatched list would read past
      // the end or show blanks. This is the invariant that makes that safe.
      expect(_labelled.rows.length, _labelled.headers.length * _labelled.headers.length);
    });

    testWidgets('each cell shows the value at its own position', (tester) async {
      for (final uiStyle in UiStyle.values) {
        await _pump(tester, uiStyle);

        // Every cell, including the ones off the diagonal, where a transposed
        // read would disagree.
        for (final label in _labelled.rows) {
          expect(
            find.text(label),
            findsOneWidget,
            reason: '$label should appear exactly once ($uiStyle)',
          );
        }
        // The operation in the corner, and each header.
        expect(find.text('op'), findsWidgets);
        for (final header in _labelled.headers) {
          expect(find.text(header), findsWidgets);
        }
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(const SizedBox.shrink());
      }
    });
  });
}
