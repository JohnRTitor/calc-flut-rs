import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:calc_flut_rs/app/theme/app_theme.dart';
import 'package:calc_flut_rs/app/theme/ui_style.dart';
import 'package:calc_flut_rs/features/calculator/presentation/providers/calculator_provider.dart';
import 'package:calc_flut_rs/features/calculator/presentation/providers/calculator_state.dart';
import 'package:calc_flut_rs/features/calculator/presentation/widgets/calc_key_spec.dart';
import 'package:calc_flut_rs/features/calculator/presentation/widgets/keypad.dart';
import 'package:calc_flut_rs/features/settings/presentation/providers/theme_provider.dart';
import 'package:calc_flut_rs/shared/widgets/app_button.dart';
import 'package:calc_flut_rs/shared/widgets/glass_utils.dart';

/// The real notifier's `build` reads memory through the Rust bridge, which
/// cannot run in a Dart-only test. Everything the keypad does here is insert or
/// toggle, none of which crosses the bridge.
class _OfflineCalculator extends Calculator {
  @override
  CalculatorState build() => const CalculatorState();
}

/// Pins the UI style, which the real notifier restores from SharedPreferences.
///
/// Necessary rather than cosmetic: the keypad reads its style from this
/// provider, not from the theme, so building a glass `AppTheme` alone would
/// have rendered the Material branch and quietly "passed" the glass half of
/// every assertion.
class _PinnedUiStyle extends UiStyleNotifier {
  _PinnedUiStyle(this.style);

  final UiStyle style;

  @override
  UiStyle build() => style;
}

/// The `keypadMinHeight` the calculator screen hands its keypad, and therefore
/// the height the keys must survive.
const double _shortScreenKeypadHeight = 450;

void main() {
  Widget host(
    Widget child, {
    required double width,
    required double height,
    required UiStyle uiStyle,
  }) {
    return ProviderScope(
      overrides: [
        calculatorProvider.overrideWith(_OfflineCalculator.new),
        uiStyleProvider.overrideWith(() => _PinnedUiStyle(uiStyle)),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme(null, uiStyle, AppColorOption.defaultColor),
        home: Scaffold(
          body: SizedBox(width: width, height: height, child: child),
        ),
      ),
    );
  }

  /// The widget that actually receives the tap for [label].
  ///
  /// Deliberately not the [AppCalcButton] itself: that widget's rendered box
  /// *includes* the padding it puts around its content, so measuring it
  /// overstates the target by 12dp and would pass on a keypad whose keys are
  /// genuinely too small. `AppCalcButton` pads with
  /// [AppCalcButton.verticalPadding] and the tap lands on what is inside it.
  Finder tappableArea(UiStyle uiStyle, String label) {
    final button = find
        .ancestor(of: find.text(label), matching: find.byType(AppCalcButton))
        .first;
    return uiStyle == UiStyle.material
        ? find.descendant(of: button, matching: find.byType(FilledButton))
        : find.descendant(of: button, matching: find.byType(SharedSurface));
  }

  for (final uiStyle in UiStyle.values) {
    final styleName = uiStyle == UiStyle.material ? 'material' : 'liquidGlass';

    group('Keypad ($styleName)', () {
      // The restructuring replaced thirty hand-nested widget blocks with a data
      // model, so these check the layout still says the same thing.
      testWidgets('lays out every key in its original position', (
        tester,
      ) async {
        await tester.pumpWidget(
          host(
            const Keypad(),
            width: 360,
            height: _shortScreenKeypadHeight,
            uiStyle: uiStyle,
          ),
        );
        await tester.pumpAndSettle();

        // Bracket row, then the digits in reading order, then MOD, then the
        // bottom action row. Each label's centre has to be above the next
        // row's, which is what "in its original position" means for a keypad.
        const labels = [
          '(',
          ')',
          '%',
          '/',
          '7',
          '8',
          '9',
          '\u00f7',
          '4',
          '5',
          '6',
          '\u00d7',
          '1',
          '2',
          '3',
          '\u2212',
          '0',
          '.',
          'MOD',
          '+',
          'AC',
          'ANS',
          '\u232b',
          '=',
        ];

        for (final label in labels) {
          expect(find.text(label), findsOneWidget, reason: 'missing $label');
        }

        double centreY(String label) => tester.getCenter(find.text(label)).dy;
        double centreX(String label) => tester.getCenter(find.text(label)).dx;

        // Six rows of four, in reading order.
        final rows = [
          for (var i = 0; i < labels.length; i += 4) labels.sublist(i, i + 4),
        ];
        expect(rows, hasLength(6));

        for (final row in rows) {
          for (final label in row) {
            expect(
              centreY(label),
              closeTo(centreY(row.first), 1.0),
              reason: 'the four keys of a row must share that row',
            );
          }
          // Keys ascend left to right within a row.
          for (var i = 1; i < row.length; i++) {
            expect(
              centreX(row[i]),
              greaterThan(centreX(row[i - 1])),
              reason: '${row[i - 1]} must sit left of ${row[i]}',
            );
          }
        }

        for (var i = 1; i < rows.length; i++) {
          expect(
            centreY(rows[i].first),
            greaterThan(centreY(rows[i - 1].first)),
            reason: 'row $i must sit below row ${i - 1}',
          );
        }
      });

      // Acceptance: measured, not assumed.
      testWidgets('every digit and operator key is at least 48dp tall', (
        tester,
      ) async {
        await tester.pumpWidget(
          host(
            const Keypad(),
            width: 360,
            height: _shortScreenKeypadHeight,
            uiStyle: uiStyle,
          ),
        );
        await tester.pumpAndSettle();

        for (final label in const [
          '(',
          ')',
          '%',
          '/',
          '7',
          '4',
          '1',
          '0',
          '.',
          'MOD',
          '+',
          'AC',
          'ANS',
          '\u232b',
        ]) {
          final size = tester.getSize(tappableArea(uiStyle, label));
          expect(
            size.height,
            greaterThanOrEqualTo(Keypad.minKeyHeight),
            reason:
                'the "$label" key is ${size.height}dp tall on the shortest '
                'supported screen; a primary control must stay hittable',
          );
          expect(
            size.width,
            greaterThanOrEqualTo(Keypad.minKeyHeight),
            reason: 'the "$label" key is only ${size.width}dp wide',
          );
        }
      });

      testWidgets('keeps its keys hittable with a scientific panel open', (
        tester,
      ) async {
        await tester.pumpWidget(
          host(
            const Keypad(),
            width: 360,
            height: _shortScreenKeypadHeight,
            uiStyle: uiStyle,
          ),
        );

        // Open the Trig panel, which costs a row of vertical space.
        await tester.tap(find.text('Sci'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Trig'));
        await tester.pumpAndSettle();

        for (final label in ['7', 'AC', '\u232b']) {
          final size = tester.getSize(tappableArea(uiStyle, label));
          expect(
            size.height,
            greaterThanOrEqualTo(Keypad.minKeyHeight),
            reason:
                'opening a secondary panel must not squeeze the main keys: '
                '"$label" fell to ${size.height}dp',
          );
        }
      });

      testWidgets('a key inserts what its label says', (tester) async {
        await tester.pumpWidget(
          host(
            const Keypad(),
            width: 360,
            height: _shortScreenKeypadHeight,
            uiStyle: uiStyle,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('7'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('+'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('5'));
        await tester.pumpAndSettle();

        final container = ProviderScope.containerOf(
          tester.element(find.byType(Keypad)),
        );
        expect(
          container.read(calculatorProvider).expression,
          '7+5',
          reason: 'the data model must still wire each key to its action',
        );
      });

      // The defect that motivated the restructure: a hidden long-press on MOD
      // that assigned tab index 2, which this screen renders as the Function
      // Evaluator.
      testWidgets('no key carries an undocumented long-press', (tester) async {
        await tester.pumpWidget(
          host(
            const Keypad(),
            width: 360,
            height: _shortScreenKeypadHeight,
            uiStyle: uiStyle,
          ),
        );
        await tester.pumpAndSettle();

        final longPresses = tester
            .widgetList<GestureDetector>(find.byType(GestureDetector))
            .where((d) => d.onLongPress != null)
            .toList();

        expect(
          longPresses,
          isEmpty,
          reason:
              'a long-press with no on-screen cue is a dead affordance: '
              '${longPresses.length} found',
        );

        // And the spec model cannot express one, so it cannot come back.
        expect(
          CalcKeySpec(
            'x',
            ButtonType.number,
            () => true,
          ).tooltip?.contains('hold'),
          anyOf(isNull, isFalse),
        );
      });

      testWidgets('survives a window measured at zero', (tester) async {
        await tester.pumpWidget(
          host(const Keypad(), width: 360, height: 0, uiStyle: uiStyle),
        );

        expect(tester.takeException(), isNull);
      });
    });
  }

  // The INV/HYP composition is the one piece of the keypad that is computed
  // rather than literal, so it is worth pinning on its own.
  group('trigKeyName', () {
    test('composes INV and HYP from the base name', () {
      expect(trigKeyName('sin', inv: false, hyp: false), 'sin');
      expect(trigKeyName('sin', inv: true, hyp: false), 'asin');
      expect(trigKeyName('sin', inv: false, hyp: true), 'sinh');
      expect(trigKeyName('sin', inv: true, hyp: true), 'asinh');
      expect(trigKeyName('cos', inv: false, hyp: false), 'cos');
      expect(trigKeyName('cos', inv: true, hyp: false), 'acos');
      expect(trigKeyName('cos', inv: false, hyp: true), 'cosh');
      expect(trigKeyName('cos', inv: true, hyp: true), 'acosh');
      expect(trigKeyName('tan', inv: false, hyp: false), 'tan');
      expect(trigKeyName('tan', inv: true, hyp: false), 'atan');
      expect(trigKeyName('tan', inv: false, hyp: true), 'tanh');
      expect(trigKeyName('tan', inv: true, hyp: true), 'atanh');
    });
  });
}
