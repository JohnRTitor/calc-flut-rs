import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:calc_flut_rs/app/theme/app_theme.dart';
import 'package:calc_flut_rs/app/theme/ui_style.dart';
import 'package:calc_flut_rs/features/calculator/presentation/providers/function_evaluator_provider.dart';
import 'package:calc_flut_rs/features/calculator/presentation/providers/function_evaluator_state.dart';
import 'package:calc_flut_rs/features/calculator/presentation/screens/function_evaluator_screen.dart';
import 'package:calc_flut_rs/features/settings/presentation/providers/theme_provider.dart';
import 'package:calc_flut_rs/shared/layouts/responsive_workspace_layout.dart';

/// The real notifier reaches the Rust bridge for its preview, so its `build`
/// is replaced with a fixed expression. The layout under test does not read the
/// preview.
class _OfflineFunctionEvaluator extends FunctionEvaluator {
  @override
  FunctionEvaluatorState build() =>
      const FunctionEvaluatorState().copyWith(funcExpression: 'x^2 + 1');
}

class _PinnedUiStyle extends UiStyleNotifier {
  _PinnedUiStyle(this.style);

  final UiStyle style;

  @override
  UiStyle build() => style;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final uiStyle in UiStyle.values) {
    final styleName = uiStyle == UiStyle.material ? 'material' : 'liquidGlass';

    group('FunctionEvaluatorScreen ($styleName)', () {
      Widget host({required double height}) {
        return ProviderScope(
          overrides: [
            functionEvaluatorProvider.overrideWith(
              _OfflineFunctionEvaluator.new,
            ),
            uiStyleProvider.overrideWith(() => _PinnedUiStyle(uiStyle)),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme(
              null,
              uiStyle,
              AppColorOption.defaultColor,
            ),
            home: Scaffold(
              body: SizedBox(
                width: 400,
                height: height,
                child: const FunctionEvaluatorScreen(),
              ),
            ),
          ),
        );
      }

      // The screen is where the user reasons about a multi-variable function,
      // and it used to answer that with a `Spacer()` that pushed the result and
      // the Evaluate button to the bottom of the viewport, leaving half the
      // screen empty. These two assertions are the difference.
      testWidgets('puts the result directly under the editor', (tester) async {
        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = const Size(400, 900);
        addTearDown(tester.view.reset);

        await tester.pumpWidget(host(height: 900));
        await tester.pumpAndSettle();

        final editor = find.byType(TextField);
        final result = find.text('Result');

        expect(editor, findsOneWidget);
        expect(result, findsOneWidget);

        expect(
          tester.getTopLeft(result).dy,
          greaterThan(tester.getBottomLeft(editor).dy),
          reason: 'the result must follow the function that produced it',
        );
      });

      testWidgets('leaves no dead zone between the editor and the result', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = const Size(400, 900);
        addTearDown(tester.view.reset);

        await tester.pumpWidget(host(height: 900));
        await tester.pumpAndSettle();

        final gap = tester.getTopLeft(find.text('Result')).dy -
            tester.getBottomLeft(find.byType(TextField)).dy;

        expect(
          gap,
          lessThan(120),
          reason:
              'a ${gap.toStringAsFixed(0)}dp gap between the question and its '
              'answer is the dead space this screen used to have; it is now a '
              'single gap token',
        );
      });

      testWidgets('is built on the shared workspace layout', (tester) async {
        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = const Size(400, 900);
        addTearDown(tester.view.reset);

        await tester.pumpWidget(host(height: 900));
        await tester.pumpAndSettle();

        // Not an assertion about an implementation detail: the point of the
        // layout primitive is that every workspace resolves "does the primary
        // action scroll or stay put" the same way, and that can only hold if
        // they all go through it.
        expect(find.byType(ResponsiveWorkspaceLayout), findsOneWidget);
      });

      testWidgets('keeps the result and the action reachable on a short screen', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = const Size(400, 600);
        addTearDown(tester.view.reset);

        await tester.pumpWidget(host(height: 600));
        await tester.pumpAndSettle();

        // Below the short-screen threshold the screen scrolls rather than
        // compressing, so nothing is squeezed out of reach.
        expect(tester.takeException(), isNull);
        expect(find.text('Result'), findsOneWidget);
        expect(
          find.text('Evaluate'),
          findsOneWidget,
          reason: 'the action must be present, if not yet on screen',
        );
      });
    });
  }
}
