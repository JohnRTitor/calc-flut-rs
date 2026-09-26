import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:calc_flut_rs/app/theme/app_theme.dart';
import 'package:calc_flut_rs/app/theme/ui_style.dart';
import 'package:calc_flut_rs/features/settings/presentation/providers/theme_provider.dart';
import 'package:calc_flut_rs/features/symbolic_math/presentation/screens/algebra_screen.dart';
import 'package:calc_flut_rs/features/symbolic_math/presentation/screens/calculus_screen.dart';
import 'package:calc_flut_rs/features/symbolic_math/presentation/widgets/symbolic_action_row.dart';
import 'package:calc_flut_rs/shared/widgets/pill_switcher.dart';

/// Pumps [home] inside the app's real theme and provider scope.
///
/// The expression is left empty on purpose: variable detection is the only part
/// of these screens that reaches the Rust bridge, and a widget test cannot call
/// it.
Future<void> _pump(WidgetTester tester, UiStyle uiStyle, Widget home) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(500, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: AppTheme.lightTheme(null, uiStyle, AppColorOption.defaultColor),
        home: home,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  // Note: the tool registry itself is deliberately not exercised here.
  // `appSections` is a top-level final that eagerly derives the converter tools
  // from the Rust bridge's category catalogue, so touching it in a widget test
  // would need the bridge initialised. `app_hub_grid_test.dart` works around
  // the same constraint by constructing hub items directly.
  group('AlgebraScreen', () {
    for (final uiStyle in UiStyle.values) {
      testWidgets('builds with an empty expression ($uiStyle)', (tester) async {
        await _pump(tester, uiStyle, const AlgebraScreen());

        expect(find.text('Algebra'), findsOneWidget);
        expect(find.byType(SymbolicActionRow), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('offers the three algebra operations up front ($uiStyle)', (
        tester,
      ) async {
        await _pump(tester, uiStyle, const AlgebraScreen());

        for (final label in ['Simplify', 'Expand', 'Factor']) {
          expect(find.text(label), findsOneWidget);
        }
        // Differentiation has its own tool.
        expect(find.text('Differentiate'), findsNothing);
      });
    }
  });

  group('CalculusScreen', () {
    for (final uiStyle in UiStyle.values) {
      testWidgets('builds with an empty expression ($uiStyle)', (tester) async {
        await _pump(tester, uiStyle, const CalculusScreen());

        expect(find.text('Calculus'), findsOneWidget);
        expect(find.byType(SymbolicActionRow), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('offers both calculus operations and no algebra ones ($uiStyle)', (
        tester,
      ) async {
        await _pump(tester, uiStyle, const CalculusScreen());

        expect(find.text('Differentiate'), findsOneWidget);
        expect(find.text('Integrate'), findsOneWidget);
        for (final label in ['Simplify', 'Expand', 'Factor']) {
          expect(find.text(label), findsNothing);
        }
      });

      testWidgets('hides the bounds until definite is chosen ($uiStyle)', (
        tester,
      ) async {
        // Bounds only exist in definite mode; showing them for an indefinite
        // integral would imply they did something to the answer.
        await _pump(tester, uiStyle, const CalculusScreen());

        expect(find.text('From'), findsNothing);
        expect(find.text('To'), findsNothing);
      });

      testWidgets('shows bounds in definite mode and offers one Integrate ($uiStyle)', (
        tester,
      ) async {
        await _pump(tester, uiStyle, const CalculusScreen());

        await tester.tap(find.byType(PillSwitcher));
        await tester.pumpAndSettle();

        expect(find.text('From'), findsOneWidget);
        expect(find.text('To'), findsOneWidget);
        // Exactly one Integrate: two identically-labelled buttons would leave
        // the user guessing which was which.
        expect(find.text('Integrate'), findsOneWidget);
        expect(find.text('Differentiate'), findsOneWidget);
      });
    }
  });
}
