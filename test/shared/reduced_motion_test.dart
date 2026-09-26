import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:calc_flut_rs/app/theme/app_theme.dart';
import 'package:calc_flut_rs/app/theme/ui_style.dart';
import 'package:calc_flut_rs/features/calculator/presentation/widgets/animated_equals_button.dart';
import 'package:calc_flut_rs/features/settings/presentation/providers/theme_provider.dart';
import 'package:calc_flut_rs/shared/layouts/breakpoints.dart';
import 'package:calc_flut_rs/shared/widgets/app_button.dart';

void main() {
  group('reduced motion', () {
    /// Wraps [child] in a media query with animations disabled, which is how
    /// the platform reports the accessibility setting.
    Widget host(Widget child, {required bool disableAnimations}) {
      return ProviderScope(
        child: MaterialApp(
          theme: AppTheme.lightTheme(
            null,
            UiStyle.material,
            AppColorOption.defaultColor,
          ),
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: disableAnimations),
            child: Scaffold(
              body: SizedBox(width: 200, height: 100, child: child),
            ),
          ),
        ),
      );
    }

    for (final uiStyle in UiStyle.values) {
      final styleName = uiStyle == UiStyle.material ? 'material' : 'liquidGlass';

      testWidgets('motion() collapses to zero when motion is reduced ($styleName)', (
        tester,
      ) async {
        late Duration normal;
        late Duration reduced;

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme(
              null,
              uiStyle,
              AppColorOption.defaultColor,
            ),
            home: Builder(
              builder: (context) {
                normal = context.motion(const Duration(milliseconds: 300));
                return MediaQuery(
                  data: const MediaQueryData(disableAnimations: true),
                  child: Builder(
                    builder: (inner) {
                      reduced = inner.motion(
                        const Duration(milliseconds: 300),
                      );
                      return const SizedBox.shrink();
                    },
                  ),
                );
              },
            ),
          ),
        );

        expect(normal, const Duration(milliseconds: 300));
        expect(reduced, Duration.zero);
      });
    }

    // The regression this guards: gating the shake on a reduced-motion
    // preference by returning early from the press handler also skipped the
    // press itself, leaving every calculator key inert for those users.
    testWidgets('a calculator key still evaluates with motion reduced', (
      tester,
    ) async {
      var presses = 0;

      await tester.pumpWidget(
        host(
          AppCalcButton(
            text: '7',
            uiStyle: UiStyle.material,
            onPressed: () {
              presses++;
              return true;
            },
          ),
          disableAnimations: true,
        ),
      );

      await tester.tap(find.text('7'));
      await tester.pumpAndSettle();

      expect(
        presses,
        1,
        reason:
            'reduced motion is a request about movement, not about whether '
            'controls work',
      );
    });

    testWidgets('a failing key still reports its failure with motion reduced', (
      tester,
    ) async {
      var presses = 0;

      await tester.pumpWidget(
        host(
          AppCalcButton(
            text: '7',
            uiStyle: UiStyle.material,
            onPressed: () {
              presses++;
              return false;
            },
          ),
          disableAnimations: true,
        ),
      );

      await tester.tap(find.text('7'));
      await tester.pumpAndSettle();

      expect(presses, 1);
      // The shake is what gets dropped; the press is not.
      expect(tester.takeException(), isNull);
    });

    testWidgets('the equals button still evaluates with motion reduced', (
      tester,
    ) async {
      var evaluations = 0;

      await tester.pumpWidget(
        host(
          AnimatedEqualsButton(
            onEvaluate: () async {
              evaluations++;
              return false;
            },
          ),
          disableAnimations: true,
        ),
      );

      await tester.tap(find.text('='));
      await tester.pumpAndSettle();

      expect(
        evaluations,
        1,
        reason: 'a failed evaluation must still be attempted and reported',
      );
    });
  });
}
