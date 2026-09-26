import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:calc_flut_rs/app/theme/app_theme.dart';
import 'package:calc_flut_rs/app/theme/ui_style.dart';
import 'package:calc_flut_rs/features/settings/presentation/providers/theme_provider.dart';
import 'package:calc_flut_rs/shared/widgets/glass_utils.dart';
import 'package:calc_flut_rs/shared/widgets/scrollable_math_result.dart';

/// The factored result from the bug report: it fits, and must render verbatim.
const String _short = '(x + 1)*(5x^2 - x + 1)';

/// Long enough to need a smaller step of the type scale, short enough to still
/// be one readable line.
const String _medium = '(x^3 + 2x^2 + x + 1)*(x^2 - 3x + 7)*(x + 1)';

/// Long enough that neither shrinking nor wrapping can save it.
const String _pathological =
    '(x^3 + 2x^2 + x + 1)*(x^2 - 3x + 7)*(x + 1)*(x^9 - 8x^8 + 28x^7)';

void main() {
  Widget host(Widget child, {double width = 320}) {
    return MaterialApp(
      theme: AppTheme.lightTheme(
        null,
        UiStyle.material,
        AppColorOption.defaultColor,
      ),
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: width, child: child),
        ),
      ),
    );
  }

  TextStyle resultStyle() => const TextStyle(fontSize: 36);

  Text findResultText(WidgetTester tester) {
    return tester.widget<Text>(
      find.descendant(
        of: find.byType(ScrollableMathResult),
        matching: find.byType(Text),
      ),
    );
  }

  for (final uiStyle in UiStyle.values) {
    final styleName = uiStyle == UiStyle.material ? 'material' : 'liquidGlass';

    group('ScrollableMathResult ($styleName)', () {
      testWidgets('renders a fitting result at full size, unwrapped', (
        tester,
      ) async {
        await tester.pumpWidget(
          host(
            ScrollableMathResult(
              expression: _short,
              uiStyle: uiStyle,
              style: resultStyle(),
            ),
            width: 800,
          ),
        );

        final text = findResultText(tester);
        expect(text.style!.fontSize, 36);
        // Nothing off screen, so no scroll view and no fade mask.
        expect(find.byType(SingleChildScrollView), findsNothing);
        expect(find.byType(ResultOverflowFade), findsNothing);
      });

      testWidgets('shrinks a long result rather than hiding part of it', (
        tester,
      ) async {
        await tester.pumpWidget(
          host(
            ScrollableMathResult(
              expression: _medium,
              uiStyle: uiStyle,
              style: resultStyle(),
            ),
            width: 800,
          ),
        );

        final text = findResultText(tester);
        expect(
          text.style!.fontSize,
          lessThan(36),
          reason: 'a result wider than its card must step down, not clip',
        );
        // Still wholly visible: no scroll affordance needed.
        expect(find.byType(ResultOverflowFade), findsNothing);
      });

      // The regression that motivated this component: a wide result used to be
      // placed in a `SingleChildScrollView(reverse: true)`, which mirrors the
      // axis so the view comes up already showing the END of the expression.
      // The opening of a factored answer — its `(x + 1)*` — therefore sat off
      // screen with nothing marking it as missing, and the visible text read as
      // a complete result while being a fragment of one.
      //
      // `reverse` is asserted directly because that is the whole defect, and
      // because `controller.offset` reads 0 in both directions: a reversed
      // scroll view reports its position through `axisDirection`, not through
      // a non-zero offset, so an offset assertion cannot see this bug at all.
      testWidgets('a scrollable result opens at its beginning, not its end', (
        tester,
      ) async {
        await tester.pumpWidget(
          host(
            ScrollableMathResult(
              expression: _pathological,
              uiStyle: uiStyle,
              style: resultStyle(),
              allowWrap: false,
            ),
            width: 240,
          ),
        );

        final scrollView = tester.widget<SingleChildScrollView>(
          find.byType(SingleChildScrollView),
        );
        expect(
          scrollView.controller!.position.maxScrollExtent,
          greaterThan(0),
          reason: 'this input is supposed to overflow',
        );
        expect(
          scrollView.reverse,
          isFalse,
          reason:
              'a reversed scroll view shows the tail of the expression first, '
              'so the head of the answer is hidden with no affordance',
        );
        expect(
          scrollView.controller!.position.axisDirection,
          AxisDirection.right,
          reason: 'content must unroll left-to-right, from its first character',
        );
      });

      testWidgets('a scrollable result marks its off-screen edge with a fade', (
        tester,
      ) async {
        await tester.pumpWidget(
          host(
            ScrollableMathResult(
              expression: _pathological,
              uiStyle: uiStyle,
              style: resultStyle(),
              allowWrap: false,
            ),
            width: 240,
          ),
        );

        // At rest, at the start, so the trailing edge is the one that fades.
        expect(find.byType(ResultOverflowFade), findsOneWidget);
        final fade = tester.widget<ResultOverflowFade>(
          find.byType(ResultOverflowFade),
        );
        expect(fade.isScrolledToStart, isTrue);
        expect(fade.isScrolledToEnd, isFalse);
      });

      testWidgets('the fade follows the scroll position to the far edge', (
        tester,
      ) async {
        await tester.pumpWidget(
          host(
            ScrollableMathResult(
              expression: _pathological,
              uiStyle: uiStyle,
              style: resultStyle(),
              allowWrap: false,
            ),
            width: 240,
          ),
        );

        final scrollView = tester.widget<SingleChildScrollView>(
          find.byType(SingleChildScrollView),
        );
        scrollView.controller!.jumpTo(
          scrollView.controller!.position.maxScrollExtent,
        );
        await tester.pump();

        final fade = tester.widget<ResultOverflowFade>(
          find.byType(ResultOverflowFade),
        );
        expect(
          fade.isScrolledToEnd,
          isTrue,
          reason: 'having reached the end, the trailing edge must stop fading',
        );
        expect(
          fade.isScrolledToStart,
          isFalse,
          reason: 'having left the start, the leading edge must now fade',
        );
      });

      // Regression: the scroll reset used to run inside `build`, which notified
      // the scroll listener and called setState while the frame was still being
      // built. Reaching it needs the user to scroll a long result and then have
      // a shorter one replace it — typing a new expression on the Algebra screen
      // does exactly that.
      testWidgets('a new answer replaces a scrolled one without throwing', (
        tester,
      ) async {
        Widget build(String expression) => MaterialApp(
          theme: AppTheme.lightTheme(
            null,
            uiStyle,
            AppColorOption.defaultColor,
          ),
          home: Scaffold(
            body: SizedBox(
              width: 240,
              child: ScrollableMathResult(
                // No key: the same State is reused across answers, which is the
                // only way to reach the bug.
                expression: expression,
                uiStyle: uiStyle,
                style: const TextStyle(fontSize: 36),
                allowWrap: false,
              ),
            ),
          ),
        );

        await tester.pumpWidget(build('(abcdefgh)*(ijklmnop)*(qrstuvwx)'));
        await tester.pumpAndSettle();

        final scrollView = tester.widget<SingleChildScrollView>(
          find.byType(SingleChildScrollView),
        );
        scrollView.controller!.jumpTo(
          scrollView.controller!.position.maxScrollExtent,
        );
        await tester.pumpAndSettle();

        await tester.pumpWidget(build('42'));
        await tester.pumpAndSettle();

        expect(
          tester.takeException(),
          isNull,
          reason:
              'a result that is no longer scrollable must not reset the '
              'offset from inside its own build',
        );
      });

      // The same reset, for the case that matters most: one long answer
      // followed by another must not inherit the previous scroll position.
      testWidgets('a second long answer starts at its beginning', (
        tester,
      ) async {
        Widget build(String expression) => MaterialApp(
          theme: AppTheme.lightTheme(
            null,
            uiStyle,
            AppColorOption.defaultColor,
          ),
          home: Scaffold(
            body: SizedBox(
              width: 240,
              child: ScrollableMathResult(
                expression: expression,
                uiStyle: uiStyle,
                style: const TextStyle(fontSize: 36),
                allowWrap: false,
              ),
            ),
          ),
        );

        await tester.pumpWidget(build('(abcdefgh)*(ijklmnop)*(qrstuvwx)'));
        await tester.pumpAndSettle();
        final first = tester.widget<SingleChildScrollView>(
          find.byType(SingleChildScrollView),
        );
        first.controller!.jumpTo(first.controller!.position.maxScrollExtent);
        await tester.pumpAndSettle();

        await tester.pumpWidget(build('(mnopqrst)*(uvwxyzab)*(cdefghij)'));
        await tester.pumpAndSettle();

        final second = tester.widget<SingleChildScrollView>(
          find.byType(SingleChildScrollView),
        );
        expect(
          second.controller!.offset,
          0,
          reason:
              'a new answer must open at its head; inheriting the previous '
              "answer's scroll position is the defect this component removes",
        );
      });

      testWidgets('survives a window that has not been measured yet', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme(
              null,
              uiStyle,
              AppColorOption.defaultColor,
            ),
            home: const Scaffold(
              body: SizedBox(
                width: 0,
                child: ScrollableMathResult(
                  expression: _pathological,
                  uiStyle: UiStyle.material,
                  style: TextStyle(fontSize: 36),
                ),
              ),
            ),
          ),
        );

        expect(tester.takeException(), isNull);
      });
    });
  }

  // A guard on the token migration that shares this file's theme of concerns:
  // the on-glass text colours are the one place raw Colors are legitimate.
  group('on-glass text tokens', () {
    testWidgets('secondary and emphasis differ only in glass mode', (
      tester,
    ) async {
      late Color materialSecondary;
      late Color glassSecondary;
      late Color materialEmphasis;
      late Color glassEmphasis;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme(
            null,
            UiStyle.material,
            AppColorOption.defaultColor,
          ),
          home: Builder(
            builder: (context) {
              materialSecondary = onGlassSecondary(context, UiStyle.material);
              materialEmphasis = onGlassEmphasis(context, UiStyle.material);
              glassSecondary = onGlassSecondary(context, UiStyle.liquidGlass);
              glassEmphasis = onGlassEmphasis(context, UiStyle.liquidGlass);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      // Material mode must defer entirely to the Material colour scheme.
      expect(materialSecondary, isNot(Colors.white70));
      expect(materialEmphasis, isNot(Colors.white));
      // Glass mode must not fall back to a Material role, or the text can lose
      // contrast against a translucent panel.
      expect(glassSecondary, Colors.white70);
      expect(glassEmphasis, Colors.white);
    });
  });
}
