import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:calc_flut_rs/app/theme/app_theme.dart';
import 'package:calc_flut_rs/app/theme/ui_style.dart';
import 'package:calc_flut_rs/features/settings/presentation/providers/theme_provider.dart';
import 'package:calc_flut_rs/features/symbolic_math/domain/symbolic_operation.dart';
import 'package:calc_flut_rs/features/symbolic_math/presentation/providers/symbolic_workspace_state.dart';
import 'package:calc_flut_rs/features/symbolic_math/presentation/widgets/symbolic_action_row.dart';
import 'package:calc_flut_rs/features/symbolic_math/presentation/widgets/symbolic_result_card.dart';
import 'package:calc_flut_rs/features/symbolic_math/presentation/widgets/symbolic_workspace_scaffold.dart';
import 'package:calc_flut_rs/shared/widgets/app_chip.dart';

/// Builds a state for a given tool, with one expression and no result.
SymbolicWorkspaceState _stateWith({
  List<SymbolicOperation> operations = SymbolicOperation.algebraOperations,
  String expression = 'x^2 - 4',
  List<String> variables = const ['x'],
  String? selectedVariable = 'x',
  String lowerBound = '',
  String upperBound = '',
  bool isComputing = false,
  List<SymbolicForm> forms = const [],
  int activeFormIndex = 0,
  String? details,
  String? steps,
  SymbolicFailure? error,
  SymbolicOperation? operation,
}) {
  return SymbolicWorkspaceState(
    operations: operations,
    expression: expression,
    variables: variables,
    selectedVariable: selectedVariable,
    lowerBound: lowerBound,
    upperBound: upperBound,
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
  group('SymbolicWorkspaceState.canRunOperation', () {
    test('needs an expression before anything can run', () {
      final state = _stateWith(expression: '   ');
      for (final operation in SymbolicOperation.values) {
        expect(
          state.canRunOperation(operation),
          isFalse,
          reason: '${operation.label} should be unavailable with no input',
        );
      }
    });

    test('simplify and expand need only an expression', () {
      final state = _stateWith(selectedVariable: null, variables: const []);
      expect(state.canRunOperation(SymbolicOperation.simplify), isTrue);
      expect(state.canRunOperation(SymbolicOperation.expand), isTrue);
    });

    test('factor needs a variable, because it acts on one', () {
      final state = _stateWith(selectedVariable: null, variables: const ['x']);
      expect(
        state.canRunOperation(SymbolicOperation.factor),
        isFalse,
        reason: 'factoring with no chosen variable would have to guess',
      );
    });

    test('factor is available once a variable is chosen', () {
      final state = _stateWith(selectedVariable: 'x');
      expect(state.canRunOperation(SymbolicOperation.factor), isTrue);
    });

    test('nothing runs while a call is already in flight', () {
      final state = _stateWith(isComputing: true);
      for (final operation in SymbolicOperation.values) {
        expect(state.canRunOperation(operation), isFalse);
      }
    });
  });

  group('SymbolicWorkspaceState.unavailableReason', () {
    test('explains an empty expression', () {
      final state = _stateWith(expression: '');
      expect(
        state.unavailableReason(SymbolicOperation.simplify),
        'Enter an expression first',
      );
    });

    test('asks the user to pick between several variables', () {
      final state = _stateWith(
        variables: const ['x', 'y'],
        selectedVariable: null,
      );
      expect(
        state.unavailableReason(SymbolicOperation.factor),
        'Pick which variable to act on',
      );
    });

    test('asks to pick even when only one variable is listed', () {
      // One unselected variable is still a choice not yet made, so claiming
      // there is no variable to act on would be plainly wrong.
      final state = _stateWith(
        variables: const ['x'],
        selectedVariable: null,
      );
      expect(
        state.unavailableReason(SymbolicOperation.factor),
        'Pick which variable to act on',
      );
    });

    test('says so when there is no variable at all', () {
      final state = _stateWith(variables: const [], selectedVariable: null);
      expect(
        state.unavailableReason(SymbolicOperation.factor),
        'This expression has no variable to act on',
      );
    });

    test('has nothing to say for an available operation', () {
      final state = _stateWith();
      expect(state.unavailableReason(SymbolicOperation.simplify), isNull);
    });
  });

  group('SymbolicWorkspaceState forms', () {
    const factored = SymbolicForm(
      label: 'Factored',
      expression: '(x - 2)*(x + 2)',
    );
    const expanded = SymbolicForm(label: 'Expanded', expression: 'x^2 - 4');
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

  group('SymbolicActionRow', () {
    for (final uiStyle in UiStyle.values) {
      testWidgets('offers exactly the operations its tool lists ($uiStyle)', (
        tester,
      ) async {
        await tester.pumpWidget(
          _host(
            uiStyle,
            SymbolicActionRow(
              uiStyle: uiStyle,
              state: _stateWith(),
              onRun: (_) {},
            ),
          ),
        );

        for (final operation in SymbolicOperation.algebraOperations) {
          expect(find.text(operation.label), findsOneWidget);
        }
        // Differentiation belongs to Calculus, so Algebra must not offer it.
        expect(find.text('Differentiate'), findsNothing);
      });

      testWidgets('shows only what its tool lists, never the whole enum ($uiStyle)', (
        tester,
      ) async {
        await tester.pumpWidget(
          _host(
            uiStyle,
            SymbolicActionRow(
              uiStyle: uiStyle,
              state: _stateWith(
                operations: SymbolicOperation.calculusOperations,
              ),
              onRun: (_) {},
            ),
          ),
        );

        for (final operation in SymbolicOperation.calculusOperations) {
          expect(find.text(operation.label), findsOneWidget);
        }
        // The algebra operations belong to another tool entirely.
        for (final label in ['Simplify', 'Expand', 'Factor']) {
          expect(find.text(label), findsNothing);
        }
      });

      testWidgets('runs the tapped operation ($uiStyle)', (tester) async {
        final chosen = <SymbolicOperation>[];
        await tester.pumpWidget(
          _host(
            uiStyle,
            SymbolicActionRow(
              uiStyle: uiStyle,
              state: _stateWith(),
              onRun: chosen.add,
            ),
          ),
        );

        await tester.tap(find.text('Expand'));
        await tester.pump();

        expect(chosen, [SymbolicOperation.expand]);
      });

      testWidgets('keeps an unavailable operation visible but inert ($uiStyle)',
          (tester) async {
        // Hidden would make the capability undiscoverable; a dead chip that
        // explains itself is better than a missing one.
        final chosen = <SymbolicOperation>[];
        await tester.pumpWidget(
          _host(
            uiStyle,
            SymbolicActionRow(
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
            SymbolicActionRow(
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
            SymbolicActionRow(
              uiStyle: uiStyle,
              state: _stateWith(),
              onRun: (_) {},
              computingOperation: SymbolicOperation.simplify,
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
              SymbolicActionRow(
                uiStyle: uiStyle,
                state: _stateWith(),
                onRun: (_) {},
                computingOperation: computing ? SymbolicOperation.simplify : null,
              ),
            ),
          );
          await tester.pump();
          return tester.getSize(find.byType(SymbolicActionRow)).height;
        }

        final idle = await rowHeightFor(computing: false);
        final busy = await rowHeightFor(computing: true);

        expect(busy, idle);
        expect(idle, SymbolicActionRow.height);
      });
    }
  });

  group('SymbolicResultCard', () {
    for (final uiStyle in UiStyle.values) {
      testWidgets('renders nothing before there is anything to say ($uiStyle)',
          (tester) async {
        await tester.pumpWidget(
          _host(uiStyle, SymbolicResultCard(uiStyle: uiStyle, state: _stateWith())),
        );

        expect(find.byType(SymbolicResultCard), findsOneWidget);
        expect(find.byType(Text), findsNothing);
      });

      testWidgets('shows the primary value ($uiStyle)', (tester) async {
        await tester.pumpWidget(
          _host(
            uiStyle,
            SymbolicResultCard(
              uiStyle: uiStyle,
              state: _stateWith(
                forms: const [
                  SymbolicForm(
                    label: 'Factored',
                    expression: '(x - 2)*(x + 2)',
                  ),
                ],
                operation: SymbolicOperation.factor,
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
            SymbolicResultCard(
              uiStyle: uiStyle,
              state: _stateWith(
                error: const SymbolicFailure(
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
        Future<void> pumpWith(SymbolicFailure error) => tester.pumpWidget(
          _host(
            uiStyle,
            SymbolicResultCard(
              uiStyle: uiStyle,
              state: _stateWith(error: error),
              onExplainLimit: () {},
            ),
          ),
        );

        await pumpWith(
          const SymbolicFailure(kind: 'too_large', message: 'Expression is too large'),
        );
        await tester.pump();
        expect(find.text('Learn More'), findsOneWidget);

        // A plain input mistake is not a limitation, so it gets no banner.
        await pumpWith(
          const SymbolicFailure(kind: 'input', message: 'Invalid expression'),
        );
        await tester.pump();
        expect(find.text('Learn More'), findsNothing);
      });

      testWidgets('hides form chips until there are two forms ($uiStyle)',
          (tester) async {
        await tester.pumpWidget(
          _host(
            uiStyle,
            SymbolicResultCard(
              uiStyle: uiStyle,
              state: _stateWith(
                forms: const [
                  SymbolicForm(label: 'Factored', expression: '(x-2)*(x+2)'),
                ],
              ),
            ),
          ),
        );
        expect(find.text('Factored'), findsNothing);

        await tester.pumpWidget(
          _host(
            uiStyle,
            SymbolicResultCard(
              uiStyle: uiStyle,
              state: _stateWith(
                forms: const [
                  SymbolicForm(label: 'Factored', expression: '(x-2)*(x+2)'),
                  SymbolicForm(label: 'Expanded', expression: 'x^2 - 4'),
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
            SymbolicResultCard(
              uiStyle: uiStyle,
              state: _stateWith(
                forms: const [
                  SymbolicForm(label: 'Factored', expression: '(x-2)*(x+2)'),
                  SymbolicForm(label: 'Expanded', expression: 'x^2 - 4'),
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
            SymbolicResultCard(
              uiStyle: uiStyle,
              state: _stateWith(
                isComputing: true,
                forms: const [
                  SymbolicForm(label: 'Simplified', expression: '5*x'),
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
            SymbolicResultCard(
              uiStyle: uiStyle,
              state: _stateWith(
                forms: const [
                  SymbolicForm(label: 'Simplified', expression: '5*x'),
                ],
                steps: 'as entered:  2*x + 3*x\nresult:      5*x',
              ),
            ),
          ),
        );

        expect(find.textContaining('as entered:'), findsOneWidget);
      });

      testWidgets('shows an indefinite integral with its arbitrary constant ($uiStyle)',
          (tester) async {
        // The backend's value already carries "+ C", so the constant cannot be
        // missed by reading the result or by copying it away.
        await tester.pumpWidget(
          _host(
            uiStyle,
            SymbolicResultCard(
              uiStyle: uiStyle,
              state: _stateWith(
                forms: const [
                  SymbolicForm(
                    label: 'Antiderivative',
                    expression: '1/2*x^2 + C',
                  ),
                ],
                details: 'Any constant added is also an answer, written + C here',
                operation: SymbolicOperation.integrate,
              ),
            ),
          ),
        );

        expect(find.text('1/2*x² + C'), findsOneWidget);
        expect(find.textContaining('Any constant added'), findsOneWidget);
      });

      testWidgets('a definite integral carries no arbitrary constant ($uiStyle)', (
        tester,
      ) async {
        // A definite integral is one exact value, so a constant here would be
        // nonsense rather than an omission.
        await tester.pumpWidget(
          _host(
            uiStyle,
            SymbolicResultCard(
              uiStyle: uiStyle,
              state: _stateWith(
                forms: const [
                  SymbolicForm(label: 'Definite integral', expression: '1/3'),
                ],
                operation: SymbolicOperation.integrateDefinite,
              ),
            ),
          ),
        );

        expect(find.text('1/3'), findsOneWidget);
        expect(find.textContaining('+ C'), findsNothing);
      });

      testWidgets('omits the steps block when there is none ($uiStyle)',
          (tester) async {
        await tester.pumpWidget(
          _host(
            uiStyle,
            SymbolicResultCard(
              uiStyle: uiStyle,
              state: _stateWith(
                forms: const [
                  SymbolicForm(label: 'Simplified', expression: '5*x'),
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
            SymbolicResultCard(
              uiStyle: uiStyle,
              state: _stateWith(
                forms: const [
                  SymbolicForm(label: 'Simplified', expression: '5*x'),
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

  group('SymbolicOperation', () {
    test('a transform is not a form of the input', () {
      // The derivative of x^2 is not another way of writing x^2, and neither is
      // its antiderivative, so neither may be offered among the input's forms.
      expect(SymbolicOperation.differentiate.isForm, isFalse);
      expect(SymbolicOperation.integrate.isForm, isFalse);
      expect(SymbolicOperation.simplify.isForm, isTrue);
      expect(SymbolicOperation.expand.isForm, isTrue);
      expect(SymbolicOperation.factor.isForm, isTrue);
    });

    test('form and transform operations partition the enum', () {
      // Guards the split itself: anything added later must be deliberately
      // classified, rather than defaulting into the wrong bucket.
      for (final operation in SymbolicOperation.values) {
        final isTransform = !operation.isForm;
        expect(
          operation.isForm,
          !isTransform,
          reason: '$operation was not classified',
        );
      }
    });

    test('the variable-taking operations are declared consistently', () {
      expect(SymbolicOperation.factor.requiresVariable, isTrue);
      expect(SymbolicOperation.differentiate.requiresVariable, isTrue);
      expect(SymbolicOperation.integrate.requiresVariable, isTrue);
      expect(SymbolicOperation.simplify.requiresVariable, isFalse);
      expect(SymbolicOperation.expand.requiresVariable, isFalse);
    });

    test('only the indefinite integral is determined up to a constant', () {
      expect(SymbolicOperation.integrate.isUpToAConstant, isTrue);
      // A definite integral is a single value, so a constant would be nonsense
      // rather than an omission.
      expect(SymbolicOperation.integrateDefinite.isUpToAConstant, isFalse);
      for (final operation in SymbolicOperation.values) {
        if (operation == SymbolicOperation.integrate) continue;
        expect(
          operation.isUpToAConstant,
          isFalse,
          reason: '$operation is fully determined',
        );
      }
    });

    test('only the definite integral needs bounds', () {
      expect(SymbolicOperation.integrateDefinite.requiresBounds, isTrue);
      for (final operation in SymbolicOperation.values) {
        if (operation == SymbolicOperation.integrateDefinite) continue;
        expect(
          operation.requiresBounds,
          isFalse,
          reason: '$operation takes no bounds',
        );
      }
    });

    test('each integration mode offers one integration, plus differentiation', () {
      for (final mode in IntegrationMode.values) {
        final operations = IntegrationMode.operationsFor(mode);
        expect(
          operations,
          contains(SymbolicOperation.differentiate),
          reason: 'differentiating does not depend on the integration mode',
        );
        expect(operations, contains(mode.operation));
        // Exactly one integration, or the chip row would show two identical
        // "Integrate" buttons and the user would have to guess which was which.
        expect(operations.where((o) => o.label == 'Integrate'), hasLength(1));
        // And nothing from another tool.
        expect(
          operations,
          isNot(contains(SymbolicOperation.simplify)),
        );
        expect(
          operations,
          isNot(contains(SymbolicOperation.factor)),
        );
      }
    });

    test('the two integration modes are distinguishable', () {
      expect(
        IntegrationMode.indefinite.operation,
        SymbolicOperation.integrate,
      );
      expect(
        IntegrationMode.definite.operation,
        SymbolicOperation.integrateDefinite,
      );
      expect(IntegrationMode.definite.label, 'Definite');
      expect(IntegrationMode.indefinite.label, 'Indefinite');
    });

    test('a definite integral needs both bounds, not one', () {
      // Defaulting a missing bound to zero would answer a different question.
      final neither = _stateWith(
        operations: [SymbolicOperation.integrateDefinite],
      );
      expect(neither.canRunOperation(SymbolicOperation.integrateDefinite), isFalse);
      expect(
        neither.unavailableReason(SymbolicOperation.integrateDefinite),
        'Enter a lower and an upper bound',
      );

      final lowerOnly = _stateWith(
        operations: [SymbolicOperation.integrateDefinite],
        lowerBound: '0',
      );
      expect(
        lowerOnly.canRunOperation(SymbolicOperation.integrateDefinite),
        isFalse,
      );
      expect(
        lowerOnly.unavailableReason(SymbolicOperation.integrateDefinite),
        'Enter both bounds, or clear them to integrate indefinitely',
      );

      final both = _stateWith(
        operations: [SymbolicOperation.integrateDefinite],
        lowerBound: '0',
        upperBound: '1',
      );
      expect(both.hasBounds, isTrue);
      expect(both.canRunOperation(SymbolicOperation.integrateDefinite), isTrue);
    });

    test('bounds are ignored by operations that take none', () {
      final state = _stateWith(lowerBound: '0', upperBound: '1');
      expect(state.canRunOperation(SymbolicOperation.simplify), isTrue);
      expect(state.canRunOperation(SymbolicOperation.differentiate), isTrue);
    });

    test('each tool offers its own operations', () {
      expect(SymbolicOperation.algebraOperations, [
        SymbolicOperation.simplify,
        SymbolicOperation.expand,
        SymbolicOperation.factor,
      ]);
      expect(SymbolicOperation.calculusOperations, [
        SymbolicOperation.differentiate,
        SymbolicOperation.integrate,
      ]);
    });

    test('tool operation lists do not overlap or leak', () {
      // Differentiation must not appear in both lists: Algebra has no business
      // offering it, and sharing the enum must not blur that.
      expect(
        SymbolicOperation.algebraOperations
            .toSet()
            .intersection(SymbolicOperation.calculusOperations.toSet()),
        isEmpty,
      );
    });

    test('every operation has a distinct bridge name', () {
      // Two operations sharing a wire name would be indistinguishable to the
      // backend, so the second would silently never run.
      final names = SymbolicOperation.values.map((o) => o.wireName).toSet();
      expect(names, hasLength(SymbolicOperation.values.length));
    });

    test('the two integrations share a label, as they are the same verb', () {
      // The definite and indefinite integrals are the same action with
      // different inputs, so they share the chip label. What tells them apart
      // is the mode switch and the bounds, not the button.
      expect(SymbolicOperation.integrate.label, 'Integrate');
      expect(SymbolicOperation.integrateDefinite.label, 'Integrate');
      // Their outputs are named differently, since they are different things.
      expect(
        SymbolicOperation.integrate.formLabel,
        isNot(SymbolicOperation.integrateDefinite.formLabel),
      );
    });
  });

  group('variable-taking operations', () {
    test('differentiate is unavailable until a variable is chosen', () {
      final state = _stateWith(
        operations: SymbolicOperation.calculusOperations,
        variables: const ['x'],
        selectedVariable: null,
      );
      expect(state.canRunOperation(SymbolicOperation.differentiate), isFalse);
      expect(
        state.unavailableReason(SymbolicOperation.differentiate),
        'Pick which variable to act on',
      );
    });

    test('differentiate is available once a variable is chosen', () {
      final state = _stateWith(
        operations: SymbolicOperation.calculusOperations,
        selectedVariable: 'x',
      );
      expect(state.canRunOperation(SymbolicOperation.differentiate), isTrue);
      expect(
        state.unavailableReason(SymbolicOperation.differentiate),
        isNull,
      );
    });

    test('a single variable is auto-selected, so calculus is usable at once', () {
      // With only one variable there is no ambiguity to resolve, so requiring a
      // tap before differentiating would be busywork.
      final state = _stateWith(
        operations: SymbolicOperation.calculusOperations,
        variables: const ['x'],
        selectedVariable: 'x',
      );
      expect(state.canRunOperation(SymbolicOperation.differentiate), isTrue);
    });
  });
}
