import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:calc_flut_rs/app/theme/app_theme.dart';
import 'package:calc_flut_rs/app/theme/ui_style.dart';
import 'package:calc_flut_rs/features/settings/presentation/providers/theme_provider.dart';
import 'package:calc_flut_rs/features/symbolic_math/presentation/providers/algebra_state.dart';
import 'package:calc_flut_rs/features/symbolic_math/presentation/widgets/algebra_action_row.dart';
import 'package:calc_flut_rs/features/symbolic_math/presentation/widgets/algebra_result_card.dart';
import 'package:calc_flut_rs/shared/widgets/app_chip.dart';

/// Builds a state with one expression and no result.
AlgebraState _stateWith({
  String expression = 'x^2 - 4',
  List<String> variables = const ['x'],
  String? selectedVariable = 'x',
  bool isComputing = false,
  List<AlgebraForm> forms = const [],
  int activeFormIndex = 0,
  String? details,
  String? steps,
  AlgebraError? error,
  AlgebraOperation? operation,
}) {
  return AlgebraState(
    expression: expression,
    variables: variables,
    selectedVariable: selectedVariable,
    isComputing: isComputing,
    forms: forms,
    activeFormIndex: activeFormIndex,
    details: details,
    steps: steps,
    error: error,
    operation: operation,
  );
}

Widget _host(UiStyle uiStyle, Widget child) {
  return MaterialApp(
    theme: AppTheme.lightTheme(null, uiStyle, AppColorOption.defaultColor),
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

void main() {
  group('AlgebraState.canRunOperation', () {
    test('needs an expression before anything can run', () {
      final state = _stateWith(expression: '   ');
      for (final operation in AlgebraOperation.values) {
        expect(
          state.canRunOperation(operation),
          isFalse,
          reason: '${operation.label} should be unavailable with no input',
        );
      }
    });

    test('simplify and expand need only an expression', () {
      final state = _stateWith(selectedVariable: null, variables: const []);
      expect(state.canRunOperation(AlgebraOperation.simplify), isTrue);
      expect(state.canRunOperation(AlgebraOperation.expand), isTrue);
    });

    test('factor needs a variable, because it acts on one', () {
      final state = _stateWith(selectedVariable: null, variables: const ['x']);
      expect(
        state.canRunOperation(AlgebraOperation.factor),
        isFalse,
        reason: 'factoring with no chosen variable would have to guess',
      );
    });

    test('factor is available once a variable is chosen', () {
      final state = _stateWith(selectedVariable: 'x');
      expect(state.canRunOperation(AlgebraOperation.factor), isTrue);
    });

    test('nothing runs while a call is already in flight', () {
      final state = _stateWith(isComputing: true);
      for (final operation in AlgebraOperation.values) {
        expect(state.canRunOperation(operation), isFalse);
      }
    });
  });

  group('AlgebraState.unavailableReason', () {
    test('explains an empty expression', () {
      final state = _stateWith(expression: '');
      expect(
        state.unavailableReason(AlgebraOperation.simplify),
        'Enter an expression first',
      );
    });

    test('asks the user to pick between several variables', () {
      final state = _stateWith(
        variables: const ['x', 'y'],
        selectedVariable: null,
      );
      expect(
        state.unavailableReason(AlgebraOperation.factor),
        'Pick which variable to factor with respect to',
      );
    });

    test('says so when there is no variable at all', () {
      final state = _stateWith(variables: const [], selectedVariable: null);
      expect(
        state.unavailableReason(AlgebraOperation.factor),
        'This expression has no variable to factor with respect to',
      );
    });

    test('has nothing to say for an available operation', () {
      final state = _stateWith();
      expect(state.unavailableReason(AlgebraOperation.simplify), isNull);
    });
  });

  group('AlgebraState forms', () {
    const factored = AlgebraForm(
      label: 'Factored',
      expression: '(x - 2)*(x + 2)',
    );
    const expanded = AlgebraForm(label: 'Expanded', expression: 'x^2 - 4');
    const twoForms = [factored, expanded];

    test('a single form is not a choice', () {
      final state = _stateWith(forms: const [factored]);
      expect(state.hasMultipleForms, isFalse);
    });

    test('two forms make the form chips meaningful', () {
      final state = _stateWith(forms: twoForms);
      expect(state.hasMultipleForms, isTrue);
    });

    test('displayValue follows the active form', () {
      final state = _stateWith(forms: twoForms, activeFormIndex: 1);
      expect(state.displayValue, 'x^2 - 4');
    });

    test('displayValue is empty before anything has run', () {
      expect(_stateWith().displayValue, '');
      expect(_stateWith().hasResult, isFalse);
    });
  });

  group('AlgebraActionRow', () {
    for (final uiStyle in UiStyle.values) {
      testWidgets('offers every operation ($uiStyle)', (tester) async {
        await tester.pumpWidget(
          _host(
            uiStyle,
            AlgebraActionRow(
              uiStyle: uiStyle,
              state: _stateWith(),
              onRun: (_) {},
            ),
          ),
        );

        for (final operation in AlgebraOperation.values) {
          expect(find.text(operation.label), findsOneWidget);
        }
      });

      testWidgets('runs the tapped operation ($uiStyle)', (tester) async {
        final chosen = <AlgebraOperation>[];
        await tester.pumpWidget(
          _host(
            uiStyle,
            AlgebraActionRow(
              uiStyle: uiStyle,
              state: _stateWith(),
              onRun: chosen.add,
            ),
          ),
        );

        await tester.tap(find.text('Expand'));
        await tester.pump();

        expect(chosen, [AlgebraOperation.expand]);
      });

      testWidgets('keeps an unavailable operation visible but inert ($uiStyle)',
          (tester) async {
        // Hidden would make the capability undiscoverable; a dead chip that
        // explains itself is better than a missing one.
        final chosen = <AlgebraOperation>[];
        await tester.pumpWidget(
          _host(
            uiStyle,
            AlgebraActionRow(
              uiStyle: uiStyle,
              state: _stateWith(variables: const [], selectedVariable: null),
              onRun: chosen.add,
            ),
          ),
        );

        expect(find.text('Factor'), findsOneWidget);

        final chip = tester.widget<AppChip>(
          find.ancestor(
            of: find.text('Factor'),
            matching: find.byType(AppChip),
          ),
        );
        expect(chip.isEnabled, isFalse);

        await tester.tap(find.text('Factor'));
        await tester.pump();
        expect(chosen, isEmpty, reason: 'a disabled chip must not fire');
      });

      testWidgets('chips meet the 40dp touch target ($uiStyle)', (tester) async {
        await tester.pumpWidget(
          _host(
            uiStyle,
            AlgebraActionRow(
              uiStyle: uiStyle,
              state: _stateWith(),
              onRun: (_) {},
            ),
          ),
        );

        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      });

      testWidgets('shows a progress indicator only on the active chip ($uiStyle)',
          (tester) async {
        await tester.pumpWidget(
          _host(
            uiStyle,
            AlgebraActionRow(
              uiStyle: uiStyle,
              state: _stateWith(),
              onRun: (_) {},
              computingOperation: AlgebraOperation.simplify,
            ),
          ),
        );

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets('the progress indicator does not resize the row ($uiStyle)',
          (tester) async {
        // A chip that grows when work starts would shift its neighbours, so the
        // indicator is drawn over the label rather than beside it.
        Future<double> rowHeightFor({required bool computing}) async {
          await tester.pumpWidget(
            _host(
              uiStyle,
              AlgebraActionRow(
                uiStyle: uiStyle,
                state: _stateWith(),
                onRun: (_) {},
                computingOperation: computing ? AlgebraOperation.simplify : null,
              ),
            ),
          );
          await tester.pump();
          return tester.getSize(find.byType(AlgebraActionRow)).height;
        }

        final idle = await rowHeightFor(computing: false);
        final busy = await rowHeightFor(computing: true);

        expect(busy, idle);
        expect(idle, AlgebraActionRow.height);
      });
    }
  });

  group('AlgebraResultCard', () {
    for (final uiStyle in UiStyle.values) {
      testWidgets('renders nothing before there is anything to say ($uiStyle)',
          (tester) async {
        await tester.pumpWidget(
          _host(uiStyle, AlgebraResultCard(uiStyle: uiStyle, state: _stateWith())),
        );

        expect(find.byType(AlgebraResultCard), findsOneWidget);
        expect(find.byType(Text), findsNothing);
      });

      testWidgets('shows the primary value ($uiStyle)', (tester) async {
        await tester.pumpWidget(
          _host(
            uiStyle,
            AlgebraResultCard(
              uiStyle: uiStyle,
              state: _stateWith(
                forms: const [
                  AlgebraForm(
                    label: 'Factored',
                    expression: '(x - 2)*(x + 2)',
                  ),
                ],
                operation: AlgebraOperation.factor,
              ),
            ),
          ),
        );

        expect(find.text('(x - 2)*(x + 2)'), findsOneWidget);
      });

      testWidgets('shows a failure in error styling, never as an answer ($uiStyle)',
          (tester) async {
        // A failure and an answer must never look alike, or a user cannot tell
        // a result from a refusal.
        await tester.pumpWidget(
          _host(
            uiStyle,
            AlgebraResultCard(
              uiStyle: uiStyle,
              state: _stateWith(
                error: const AlgebraError(
                  kind: 'input',
                  message: 'Invalid expression: unexpected end of input',
                  suggestion: 'Check for a missing operator',
                ),
              ),
            ),
          ),
        );

        expect(find.textContaining('Invalid expression'), findsOneWidget);
        expect(find.text('Check for a missing operator'), findsOneWidget);
      });

      testWidgets('offers Learn More only for a practical limit ($uiStyle)',
          (tester) async {
        Future<void> pumpWith(AlgebraError error) => tester.pumpWidget(
          _host(
            uiStyle,
            AlgebraResultCard(
              uiStyle: uiStyle,
              state: _stateWith(error: error),
              onExplainLimit: () {},
            ),
          ),
        );

        await pumpWith(
          const AlgebraError(kind: 'too_large', message: 'Expression is too large'),
        );
        await tester.pump();
        expect(find.text('Learn More'), findsOneWidget);

        // A plain input mistake is not a limitation, so it gets no banner.
        await pumpWith(
          const AlgebraError(kind: 'input', message: 'Invalid expression'),
        );
        await tester.pump();
        expect(find.text('Learn More'), findsNothing);
      });

      testWidgets('hides form chips until there are two forms ($uiStyle)',
          (tester) async {
        await tester.pumpWidget(
          _host(
            uiStyle,
            AlgebraResultCard(
              uiStyle: uiStyle,
              state: _stateWith(
                forms: const [
                  AlgebraForm(label: 'Factored', expression: '(x-2)*(x+2)'),
                ],
              ),
            ),
          ),
        );
        expect(find.text('Factored'), findsNothing);

        await tester.pumpWidget(
          _host(
            uiStyle,
            AlgebraResultCard(
              uiStyle: uiStyle,
              state: _stateWith(
                forms: const [
                  AlgebraForm(label: 'Factored', expression: '(x-2)*(x+2)'),
                  AlgebraForm(label: 'Expanded', expression: 'x^2 - 4'),
                ],
              ),
            ),
          ),
        );
        expect(find.text('Factored'), findsOneWidget);
        expect(find.text('Expanded'), findsOneWidget);
      });

      testWidgets('switches form when a chip is tapped ($uiStyle)', (tester) async {
        final picked = <int>[];
        await tester.pumpWidget(
          _host(
            uiStyle,
            AlgebraResultCard(
              uiStyle: uiStyle,
              state: _stateWith(
                forms: const [
                  AlgebraForm(label: 'Factored', expression: '(x-2)*(x+2)'),
                  AlgebraForm(label: 'Expanded', expression: 'x^2 - 4'),
                ],
              ),
              onShowForm: picked.add,
            ),
          ),
        );

        await tester.tap(find.text('Expanded'));
        await tester.pump();

        expect(picked, [1]);
      });

      testWidgets('keeps the previous value visible while computing ($uiStyle)',
          (tester) async {
        // The card must never blank out during work it is still doing.
        await tester.pumpWidget(
          _host(
            uiStyle,
            AlgebraResultCard(
              uiStyle: uiStyle,
              state: _stateWith(
                isComputing: true,
                forms: const [
                  AlgebraForm(label: 'Simplified', expression: '5*x'),
                ],
              ),
            ),
          ),
        );

        expect(find.text('5x'), findsOneWidget);
      });

      testWidgets('shows step-by-step working when present ($uiStyle)',
          (tester) async {
        await tester.pumpWidget(
          _host(
            uiStyle,
            AlgebraResultCard(
              uiStyle: uiStyle,
              state: _stateWith(
                forms: const [
                  AlgebraForm(label: 'Simplified', expression: '5*x'),
                ],
                steps: 'as entered:  2*x + 3*x\nresult:      5*x',
              ),
            ),
          ),
        );

        expect(find.textContaining('as entered:'), findsOneWidget);
      });

      testWidgets('omits the steps block when there is none ($uiStyle)',
          (tester) async {
        await tester.pumpWidget(
          _host(
            uiStyle,
            AlgebraResultCard(
              uiStyle: uiStyle,
              state: _stateWith(
                forms: const [
                  AlgebraForm(label: 'Simplified', expression: '5*x'),
                ],
              ),
            ),
          ),
        );

        expect(find.textContaining('as entered:'), findsNothing);
      });

      testWidgets('exposes copy as an explicit button ($uiStyle)', (tester) async {
        var copies = 0;
        await tester.pumpWidget(
          _host(
            uiStyle,
            AlgebraResultCard(
              uiStyle: uiStyle,
              state: _stateWith(
                forms: const [
                  AlgebraForm(label: 'Simplified', expression: '5*x'),
                ],
              ),
              onCopy: () => copies++,
            ),
          ),
        );

        // An undiscoverable long-press is the pattern being avoided here.
        expect(find.byTooltip('Copy result'), findsOneWidget);

        await tester.tap(find.byTooltip('Copy result'));
        await tester.pump();
        expect(copies, 1);
      });
    }
  });

  group('SymbolicComputeTimings', () {
    test('are named constants, not magic numbers', () {
      // Tunable after release without hunting through build methods.
      expect(SymbolicComputeTimings.indicatorDelay.inMilliseconds, greaterThan(0));
      expect(SymbolicComputeTimings.slowCallNotice.inMilliseconds, greaterThan(0));
      expect(
        SymbolicComputeTimings.slowCallNotice,
        greaterThan(SymbolicComputeTimings.indicatorDelay),
      );
    });
  });
}
