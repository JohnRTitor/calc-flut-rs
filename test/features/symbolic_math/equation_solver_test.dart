import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:calc_flut_rs/app/theme/app_theme.dart';
import 'package:calc_flut_rs/app/theme/ui_style.dart';
import 'package:calc_flut_rs/features/settings/presentation/providers/theme_provider.dart';
import 'package:calc_flut_rs/features/symbolic_math/presentation/providers/equation_solver_state.dart';
import 'package:calc_flut_rs/features/symbolic_math/presentation/providers/symbolic_workspace_state.dart';
import 'package:calc_flut_rs/features/symbolic_math/presentation/widgets/symbolic_solve_result_card.dart';
import 'package:calc_flut_rs/generated/rust/bridge/symbolic.dart' as rust_symbolic;

EquationSolverState _stateWith({
  String equation = 'x^2 = 4',
  List<String> variables = const ['x'],
  String? selectedVariable = 'x',
  List<String> solutions = const [],
  rust_symbolic.SolutionKind? solutionKind,
  String? details,
  String? steps,
  SymbolicFailure? error,
  bool isComputing = false,
}) {
  return EquationSolverState(
    equation: equation,
    variables: variables,
    selectedVariable: selectedVariable,
    solutions: solutions,
    solutionKind: solutionKind,
    details: details,
    steps: steps,
    error: error,
    isComputing: isComputing,
  );
}

Widget _host(UiStyle uiStyle, Widget child) {
  return MaterialApp(
    theme: AppTheme.lightTheme(null, uiStyle, AppColorOption.defaultColor),
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

void main() {
  group('EquationSolverState', () {
    test('needs an equation before anything can run', () {
      final state = _stateWith(equation: '   ');
      expect(state.canSolve, isFalse);
      expect(state.unavailableReason(), 'Enter an equation first');
    });

    test('needs a variable to solve for', () {
      final state = _stateWith(
        variables: const ['x', 'y'],
        selectedVariable: null,
      );
      expect(state.canRun, isFalse);
      expect(state.unavailableReason(), 'Pick which variable to solve for');
    });

    test('asks to pick even when only one variable is listed', () {
      final state = _stateWith(selectedVariable: null);
      expect(state.unavailableReason(), 'Pick which variable to solve for');
    });

    test('says so when there is no variable to solve for', () {
      final state = _stateWith(variables: const [], selectedVariable: null);
      expect(
        state.unavailableReason(),
        'This equation has no variable to solve for',
      );
    });

    test('is runnable once an equation and variable are present', () {
      final state = _stateWith();
      expect(state.canRun, isTrue);
      expect(state.unavailableReason(), isNull);
    });

    test('nothing runs while a solve is in flight', () {
      final state = _stateWith(isComputing: true);
      expect(state.canRun, isFalse);
      expect(state.unavailableReason(), 'Working on the previous result');
    });

    test('classifies each of the four outcomes', () {
      expect(
        _stateWith(
          solutions: const ['2'],
          solutionKind: rust_symbolic.SolutionKind.unique,
        ).hasMultipleSolutions,
        isFalse,
      );
      expect(
        _stateWith(
          solutions: const ['2', '-2'],
          solutionKind: rust_symbolic.SolutionKind.multiple,
        ).hasMultipleSolutions,
        isTrue,
      );
      expect(
        _stateWith(solutionKind: rust_symbolic.SolutionKind.infinite).isInfinite,
        isTrue,
      );
      expect(
        _stateWith(solutionKind: rust_symbolic.SolutionKind.none).hasNoSolution,
        isTrue,
      );
    });

    test('no outcome is ever a failure', () {
      // The whole point: none of the four is an error state.
      for (final kind in rust_symbolic.SolutionKind.values) {
        final state = _stateWith(solutionKind: kind);
        expect(state.error, isNull, reason: '$kind must not be an error');
        expect(state.hasResult, isTrue, reason: '$kind is a result');
      }
    });
  });

  group('SymbolicSolveResultCard', () {
    for (final uiStyle in UiStyle.values) {
      testWidgets('renders nothing before a solve has run ($uiStyle)', (
        tester,
      ) async {
        await tester.pumpWidget(
          _host(uiStyle, SymbolicSolveResultCard(uiStyle: uiStyle, state: _stateWith())),
        );

        expect(find.byType(SymbolicSolveResultCard), findsOneWidget);
        expect(find.byType(Text), findsNothing);
      });

      testWidgets('a unique solution looks like any other value ($uiStyle)', (
        tester,
      ) async {
        await tester.pumpWidget(
          _host(
            uiStyle,
            SymbolicSolveResultCard(
              uiStyle: uiStyle,
              state: _stateWith(
                solutions: const ['1/3'],
                solutionKind: rust_symbolic.SolutionKind.unique,
              ),
            ),
          ),
        );

        expect(find.text('1/3'), findsOneWidget);
        // No list chrome for a single value.
        expect(find.byTooltip('Copy 1/3'), findsNothing);
      });

      testWidgets('several solutions list them, each copyable ($uiStyle)', (
        tester,
      ) async {
        await tester.pumpWidget(
          _host(
            uiStyle,
            SymbolicSolveResultCard(
              uiStyle: uiStyle,
              state: _stateWith(
                solutions: const ['2', '-2'],
                solutionKind: rust_symbolic.SolutionKind.multiple,
              ),
            ),
          ),
        );

        expect(find.text('x = 2'), findsOneWidget);
        expect(find.text('x = -2'), findsOneWidget);
        // Copying one root is the common case, so it is offered per row.
        expect(find.byTooltip('Copy 2'), findsOneWidget);
        expect(find.byTooltip('Copy -2'), findsOneWidget);
      });

      testWidgets('an identity is stated in words, not listed ($uiStyle)', (
        tester,
      ) async {
        await tester.pumpWidget(
          _host(
            uiStyle,
            SymbolicSolveResultCard(
              uiStyle: uiStyle,
              state: _stateWith(
                solutionKind: rust_symbolic.SolutionKind.infinite,
              ),
            ),
          ),
        );

        // Said once, in words. The backend deliberately sends no qualifier here,
        // because the card already names the outcome.
        expect(find.textContaining('Every value'), findsOneWidget);
        expect(find.byTooltip('Copy 2'), findsNothing);
      });

      testWidgets('no solution is an answer, not an error ($uiStyle)', (
        tester,
      ) async {
        await tester.pumpWidget(
          _host(
            uiStyle,
            SymbolicSolveResultCard(
              uiStyle: uiStyle,
              state: _stateWith(
                solutionKind: rust_symbolic.SolutionKind.none,
              ),
            ),
          ),
        );

        expect(find.text('No solution'), findsOneWidget);

        // The styling must not read as a failure: the user did nothing wrong.
        final texts = tester.widgetList<Text>(find.byType(Text));
        final noSolution = texts.firstWhere((t) => t.data == 'No solution');
        final errorColour = Theme.of(
          tester.element(find.byType(SymbolicSolveResultCard)),
        ).colorScheme.error;
        expect(
          noSolution.style?.color,
          isNot(errorColour),
          reason: '"No solution" is a correct answer and must not be styled as one',
        );
      });

      testWidgets('complex roots read as i, not as a variable named I ($uiStyle)',
          (tester) async {
        await tester.pumpWidget(
          _host(
            uiStyle,
            SymbolicSolveResultCard(
              uiStyle: uiStyle,
              state: _stateWith(
                solutions: const ['I', '-I'],
                solutionKind: rust_symbolic.SolutionKind.multiple,
              ),
            ),
          ),
        );

        expect(find.text('x = i'), findsOneWidget);
        expect(find.text('x = -i'), findsOneWidget);
      });

      testWidgets('a genuine failure is styled as an error ($uiStyle)', (
        tester,
      ) async {
        await tester.pumpWidget(
          _host(
            uiStyle,
            SymbolicSolveResultCard(
              uiStyle: uiStyle,
              state: _stateWith(
                error: const SymbolicFailure(
                  kind: 'input',
                  message: 'That is an expression, not an equation',
                  suggestion: 'Try something like x^2 - 4 = 0',
                ),
              ),
            ),
          ),
        );

        final texts = tester.widgetList<Text>(find.byType(Text));
        final message = texts.firstWhere((t) => t.data?.contains('not an equation') ?? false);
        final errorColour = Theme.of(
          tester.element(find.byType(SymbolicSolveResultCard)),
        ).colorScheme.error;
        expect(message.style?.color, errorColour);
        expect(find.text('Try something like x^2 - 4 = 0'), findsOneWidget);
      });

      testWidgets('shows the qualifier and steps when present ($uiStyle)', (
        tester,
      ) async {
        await tester.pumpWidget(
          _host(
            uiStyle,
            SymbolicSolveResultCard(
              uiStyle: uiStyle,
              state: _stateWith(
                solutionKind: rust_symbolic.SolutionKind.none,
                details: '1 candidate discarded: it did not satisfy the original equation',
                steps: 'equation:  x^2 = 4\nsolve for: x',
              ),
            ),
          ),
        );

        expect(find.textContaining('discarded'), findsOneWidget);
        expect(find.textContaining('solve for: x'), findsOneWidget);
      });

      testWidgets('a discarded candidate is never hidden ($uiStyle)', (
        tester,
      ) async {
        // A quietly shorter answer would look like the whole truth.
        await tester.pumpWidget(
          _host(
            uiStyle,
            SymbolicSolveResultCard(
              uiStyle: uiStyle,
              state: _stateWith(
                solutionKind: rust_symbolic.SolutionKind.none,
                details: '1 candidate discarded',
              ),
            ),
          ),
        );

        expect(find.text('1 candidate discarded'), findsOneWidget);
      });
    }
  });
}
