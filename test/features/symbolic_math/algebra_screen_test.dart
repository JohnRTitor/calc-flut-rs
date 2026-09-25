import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:calc_flut_rs/app/theme/app_theme.dart';
import 'package:calc_flut_rs/app/theme/ui_style.dart';
import 'package:calc_flut_rs/features/settings/presentation/providers/theme_provider.dart';
import 'package:calc_flut_rs/features/symbolic_math/presentation/screens/algebra_screen.dart';
import 'package:calc_flut_rs/features/symbolic_math/presentation/widgets/algebra_action_row.dart';

void main() {
  // Note: the tool registry itself is deliberately not exercised here.
  // `appSections` is a top-level final that eagerly derives the converter
  // tools from the Rust bridge's category catalogue, so touching it in a widget
  // test would need the bridge initialised. `app_hub_grid_test.dart` works
  // around the same constraint by constructing hub items directly.
  group('AlgebraScreen', () {
    for (final uiStyle in UiStyle.values) {
      testWidgets('builds with an empty expression ($uiStyle)', (tester) async {
        // Deliberately leaves the expression empty: variable detection is the
        // only part of this screen that reaches the Rust bridge, and a widget
        // test cannot call it.
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = const Size(500, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: AppTheme.lightTheme(
                null,
                uiStyle,
                AppColorOption.defaultColor,
              ),
              home: const AlgebraScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Algebra'), findsOneWidget);
        expect(find.byType(AlgebraActionRow), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('offers all three operations up front ($uiStyle)', (
        tester,
      ) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = const Size(500, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: AppTheme.lightTheme(
                null,
                uiStyle,
                AppColorOption.defaultColor,
              ),
              home: const AlgebraScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        for (final label in ['Simplify', 'Expand', 'Factor']) {
          expect(find.text(label), findsOneWidget);
        }
      });
    }
  });
}

