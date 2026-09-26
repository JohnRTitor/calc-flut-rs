import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:calc_flut_rs/app/theme/app_theme.dart';
import 'package:calc_flut_rs/app/theme/ui_style.dart';
import 'package:calc_flut_rs/features/history/presentation/providers/history_provider.dart';
import 'package:calc_flut_rs/features/settings/presentation/providers/theme_provider.dart';
import 'package:calc_flut_rs/features/symbolic_math/presentation/providers/matrix_workspace.dart';
import 'package:calc_flut_rs/features/symbolic_math/presentation/providers/number_theory_workspace.dart';
import 'package:calc_flut_rs/features/symbolic_math/presentation/providers/symbolic_history.dart';
import 'package:calc_flut_rs/features/symbolic_math/presentation/providers/symbolic_workspace_state.dart';
import 'package:calc_flut_rs/features/symbolic_math/presentation/providers/symbolic_workspace.dart';
import 'package:calc_flut_rs/features/symbolic_math/presentation/widgets/matrix_input_grid.dart';
import 'package:calc_flut_rs/features/symbolic_math/presentation/widgets/matrix_result_panel.dart';
import 'package:calc_flut_rs/features/symbolic_math/presentation/widgets/number_result_panel.dart';
import 'package:calc_flut_rs/generated/rust/bridge/symbolic.dart'
    as rust_symbolic;
import 'package:calc_flut_rs/generated/rust/shared/history.dart';
import 'package:calc_flut_rs/shared/widgets/symbolic_primary_action.dart';

/// Stands in for the real notifier, whose `build` reads history through the
/// Rust bridge and cannot run in a Dart-only test.
class _EmptyHistory extends History {
  @override
  Future<List<HistoryEntry>> build() async => const [];
}

/// Hands the test the [WidgetRef] that the history restore entry point needs.
class _RefCapture extends ConsumerWidget {
  const _RefCapture(this.onRef);

  final ValueChanged<WidgetRef> onRef;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    onRef(ref);
    return const SizedBox.shrink();
  }
}

Widget _host(UiStyle uiStyle, Widget child) {
  return MaterialApp(
    theme: AppTheme.lightTheme(null, uiStyle, AppColorOption.defaultColor),
    home: Scaffold(
      body: SingleChildScrollView(child: SizedBox(width: 500, child: child)),
    ),
  );
}

/// A matrix analysis with every optional field absent, which is the case worth
/// checking: a singular or non-square matrix leaves them empty, and a row with
/// nothing in it invites reading it as a zero.
rust_symbolic.MatrixAnalysisResponse _bareMatrixAnalysis() =>
    rust_symbolic.MatrixAnalysisResponse(
      rank: 1,
      reduced: const ['1', '0', '0', '1'],
      columns: 2,
    );

rust_symbolic.NumberAnalysisResponse _numberAnalysis() {
  return rust_symbolic.NumberAnalysisResponse(
    isPrime: false,
    isSquare: false,
    isPerfect: false,
    isCarmichael: false,
    factors: const [
      rust_symbolic.PrimePower(prime: '2', power: 3),
      rust_symbolic.PrimePower(prime: '3', power: 2),
      rust_symbolic.PrimePower(prime: '5', power: 1),
    ],
    divisors: const ['1', '2', '3'],
    divisorCount: 3,
    divisorSum: '6',
    totient: '12',
    nextPrime: '97',
    previousPrime: '89',
    details: null,
  );
}

void main() {
  group('MatrixInputGrid', () {
    for (final uiStyle in UiStyle.values) {
      testWidgets('shows one field per cell ($uiStyle)', (tester) async {
        await tester.pumpWidget(
          _host(
            uiStyle,
            MatrixInputGrid(
              uiStyle: uiStyle,
              cells: const [
                ['1', '2'],
                ['3', '4'],
              ],
              onChanged: (_) {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(TextField), findsNWidgets(4));
        expect(tester.takeException(), isNull);
      });

      testWidgets('adds a row, filling it with zeros ($uiStyle)', (
        tester,
      ) async {
        var latest = <List<String>>[];
        await tester.pumpWidget(
          _host(
            uiStyle,
            MatrixInputGrid(
              uiStyle: uiStyle,
              cells: const [
                ['1', '2'],
              ],
              onChanged: (cells) => latest = cells,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(TextButton, 'Row'));
        await tester.pumpAndSettle();

        expect(latest, hasLength(2));
        expect(latest.last, ['0', '0']);
      });

      testWidgets('adds a column to every row ($uiStyle)', (tester) async {
        var latest = <List<String>>[];
        await tester.pumpWidget(
          _host(
            uiStyle,
            MatrixInputGrid(
              uiStyle: uiStyle,
              cells: const [
                ['1', '2'],
                ['3', '4'],
              ],
              onChanged: (cells) => latest = cells,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(TextButton, 'Column'));
        await tester.pumpAndSettle();

        expect(latest.first, hasLength(3));
        expect(latest.last, hasLength(3));
      });

      testWidgets('starts from a usable grid ($uiStyle)', (tester) async {
        // A 2x2 identity is a real matrix, not a blank slate the user has to
        // fill in before anything can happen.
        final cells = MatrixInputGrid.initialCells();
        expect(cells, hasLength(2));
        expect(cells.every((row) => row.length == 2), isTrue);
      });

      testWidgets('adopts a grid replaced from outside ($uiStyle)', (
        tester,
      ) async {
        // Restoring from history swaps the whole grid at once. If the widget
        // treated its own first keystroke as a permanent reason to ignore
        // outside changes, the fields would keep the old numbers and the
        // restored matrix would never reach the screen.
        var cells = const [
          ['1', '2'],
          ['3', '4'],
        ];
        late StateSetter setOuter;
        await tester.pumpWidget(
          _host(
            uiStyle,
            StatefulBuilder(
              builder: (context, setState) {
                setOuter = setState;
                return MatrixInputGrid(
                  uiStyle: uiStyle,
                  cells: cells,
                  onChanged: (_) {},
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Type into a field, so the widget has made an edit of its own.
        await tester.enterText(find.byType(TextField).first, '9');
        await tester.pumpAndSettle();

        setOuter(() {
          cells = const [
            ['7', '8'],
            ['9', '10'],
          ];
        });
        await tester.pumpAndSettle();

        final fields = tester.widgetList<TextField>(find.byType(TextField));
        expect(fields.map((f) => f.controller?.text).toList(), [
          '7',
          '8',
          '9',
          '10',
        ]);
      });

      testWidgets('keeps what was typed when the parent echoes it back', (
        tester,
      ) async {
        // The normal path: the parent stores what the widget reported and hands
        // it straight back. The fields must show the typed value, not be reset
        // to the grid as it was before the keystroke.
        var cells = const [
          ['1', '2'],
          ['3', '4'],
        ];
        late StateSetter setOuter;
        await tester.pumpWidget(
          _host(
            uiStyle,
            StatefulBuilder(
              builder: (context, setState) {
                setOuter = setState;
                return MatrixInputGrid(
                  uiStyle: uiStyle,
                  cells: cells,
                  onChanged: (next) => setState(() => cells = next),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField).first, '9');
        await tester.pumpAndSettle();

        setOuter(() {});
        await tester.pumpAndSettle();

        final fields = tester.widgetList<TextField>(find.byType(TextField));
        expect(fields.map((f) => f.controller?.text).toList(), [
          '9',
          '2',
          '3',
          '4',
        ]);
      });
    }
  });

  group('MatrixState', () {
    test('needs a non-empty grid before analysing', () {
      const empty = MatrixState();
      expect(empty.canAnalyse, isFalse);
      expect(empty.unavailableReason(), 'Enter at least one cell');

      const filled = MatrixState(
        cells: [
          ['1'],
        ],
      );
      expect(filled.canAnalyse, isTrue);
      expect(filled.unavailableReason(), isNull);
    });

    test('nothing runs while an analysis is in flight', () {
      const state = MatrixState(
        cells: [
          ['1'],
        ],
        isComputing: true,
      );
      expect(state.canAnalyse, isFalse);
      expect(state.unavailableReason(), 'Working on the previous result');
    });
  });

  group('MatrixResultPanel', () {
    for (final uiStyle in UiStyle.values) {
      testWidgets('renders nothing before an analysis has run ($uiStyle)', (
        tester,
      ) async {
        await tester.pumpWidget(
          _host(
            uiStyle,
            MatrixResultPanel(
              uiStyle: uiStyle,
              state: const MatrixState(
                cells: [
                  ['1'],
                ],
              ),
            ),
          ),
        );

        expect(find.byType(MatrixResultPanel), findsOneWidget);
        expect(find.text('Rank'), findsNothing);
      });

      testWidgets(
        'omits absent quantities rather than showing them empty ($uiStyle)',
        (tester) async {
          // A singular matrix has no inverse. Drawing an "Inverse" row with nothing
          // in it would read as an inverse of zero.
          await tester.pumpWidget(
            _host(
              uiStyle,
              MatrixResultPanel(
                uiStyle: uiStyle,
                state: MatrixState(
                  cells: const [
                    ['1'],
                  ],
                  analysis: _bareMatrixAnalysis(),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // The rank is always there.
          expect(find.text('Rank'), findsOneWidget);
          expect(find.text('1'), findsWidgets);
          // The things that do not apply are not shown at all.
          expect(find.text('Determinant'), findsNothing);
          expect(find.text('Inverse'), findsNothing);
          expect(find.text('Trace'), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'labels each eigenvector with its own eigenvalue ($uiStyle)',
        (tester) async {
          // Eigenvalues and eigenvectors do not line up when one repeats, so a
          // vector shown without its eigenvalue would be ambiguous.
          await tester.pumpWidget(
            _host(
              uiStyle,
              MatrixResultPanel(
                uiStyle: uiStyle,
                state: MatrixState(
                  cells: const [
                    ['1', '0'],
                    ['0', '1'],
                  ],
                  analysis: rust_symbolic.MatrixAnalysisResponse(
                    rank: 2,
                    reduced: const ['1', '0', '0', '1'],
                    columns: 2,
                    eigenvalues: const ['1', '1'],
                    eigenvectors: const [
                      rust_symbolic.EigenPair(
                        eigenvalue: '1',
                        vector: ['1', '0'],
                        eigenspaceDimension: 2,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('Eigenvector for 1'), findsOneWidget);
          expect(find.text('1,   0'), findsOneWidget);
        },
      );

      testWidgets('rebuilds the rows from the flat cells ($uiStyle)', (
        tester,
      ) async {
        // The bridge sends one flat list, because it cannot encode a nested
        // vector. Chunks are cut at the carried width. A square matrix would
        // hide a mistake here, since the transposed reading of a square matrix
        // has the same entries in the same places, so these cells are
        // position-labelled: r1c1 and such, where every entry is distinct.
        await tester.pumpWidget(
          _host(
            uiStyle,
            MatrixResultPanel(
              uiStyle: uiStyle,
              state: MatrixState(
                cells: const [
                  ['r1c1', 'r1c2', 'r1c3'],
                  ['r2c1', 'r2c2', 'r2c3'],
                ],
                analysis: rust_symbolic.MatrixAnalysisResponse(
                  rank: 2,
                  reduced: const [
                    'r1c1',
                    'r1c2',
                    'r1c3',
                    'r2c1',
                    'r2c2',
                    'r2c3',
                  ],
                  columns: 3,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Row-major, not column-major: the first chunk is the first row.
        expect(
          find.text('[r1c1  r1c2  r1c3]\n[r2c1  r2c2  r2c3]'),
          findsOneWidget,
        );
      });

      testWidgets('draws nothing for a matrix it cannot shape ($uiStyle)', (
        tester,
      ) async {
        // A width of zero would otherwise divide the chunking loop by nothing,
        // or spin it. Refusing to guess is the only honest reading.
        await tester.pumpWidget(
          _host(
            uiStyle,
            MatrixResultPanel(
              uiStyle: uiStyle,
              state: MatrixState(
                cells: const [
                  ['1', '2'],
                ],
                analysis: rust_symbolic.MatrixAnalysisResponse(
                  rank: 1,
                  reduced: const ['1', '2'],
                  columns: 0,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Reduced form'), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('NumberTheoryState', () {
    test('needs a number before analysing', () {
      const empty = NumberTheoryState();
      expect(empty.canAnalyse, isFalse);

      const filled = NumberTheoryState(number: '360');
      expect(filled.canAnalyse, isTrue);
    });

    test('the pair operations need both numbers', () {
      const one = NumberTheoryState(number: '12');
      expect(one.canCompare, isFalse);
      const both = NumberTheoryState(number: '12', other: '18');
      expect(both.canCompare, isTrue);
    });

    test('pair results are detectable so the panel can show them alone', () {
      const none = NumberTheoryState(number: '12', other: '18');
      expect(none.hasPairResult, isFalse);
      const withGcd = NumberTheoryState(number: '12', other: '18', gcd: '6');
      expect(withGcd.hasPairResult, isTrue);
    });
  });

  group('NumberResultPanel', () {
    for (final uiStyle in UiStyle.values) {
      testWidgets('renders nothing before an analysis has run ($uiStyle)', (
        tester,
      ) async {
        await tester.pumpWidget(
          _host(
            uiStyle,
            NumberResultPanel(
              uiStyle: uiStyle,
              state: const NumberTheoryState(number: '360'),
            ),
          ),
        );

        expect(find.text('Factorisation'), findsNothing);
      });

      testWidgets('shows the factorisation with its powers ($uiStyle)', (
        tester,
      ) async {
        await tester.pumpWidget(
          _host(
            uiStyle,
            NumberResultPanel(
              uiStyle: uiStyle,
              state: NumberTheoryState(
                number: '360',
                analysis: _numberAnalysis(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // A power of one is written bare, and higher powers carry an exponent.
        expect(find.text('2^3 * 3^2 * 5'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('leaves out a quantity that has no value ($uiStyle)', (
        tester,
      ) async {
        // The totient of 0 is not 0; showing a 0 there would be a real answer
        // rather than an absent one.
        await tester.pumpWidget(
          _host(
            uiStyle,
            NumberResultPanel(
              uiStyle: uiStyle,
              state: NumberTheoryState(
                number: '0',
                analysis: rust_symbolic.NumberAnalysisResponse(
                  isPrime: false,
                  isSquare: false,
                  isPerfect: false,
                  isCarmichael: false,
                  factors: const [],
                  divisors: const [],
                  divisorCount: 0,
                  divisorSum: '',
                  totient: '',
                  nextPrime: '2',
                  previousPrime: '',
                  details: '0 has no prime factorisation.',
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text("Euler's totient"), findsNothing);
        expect(find.text('Divisor sum'), findsNothing);
        expect(find.text('Factorisation'), findsNothing);
        // The reason is shown instead.
        expect(find.textContaining('no prime factorisation'), findsOneWidget);
      });

      testWidgets('names which numbers the pair result is about ($uiStyle)', (
        tester,
      ) async {
        await tester.pumpWidget(
          _host(
            uiStyle,
            NumberResultPanel(
              uiStyle: uiStyle,
              state: const NumberTheoryState(
                number: '12',
                other: '18',
                gcd: '6',
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('gcd(12, 18) = 6'), findsOneWidget);
      });

      testWidgets(
        'states coprimality in words, not a bare boolean ($uiStyle)',
        (tester) async {
          await tester.pumpWidget(
            _host(
              uiStyle,
              NumberResultPanel(
                uiStyle: uiStyle,
                state: const NumberTheoryState(
                  number: '8',
                  other: '15',
                  coprime: true,
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(
            find.textContaining('no common factor other than 1'),
            findsOneWidget,
          );
        },
      );

      testWidgets('shows what to do about a failure, not just that it failed', (
        tester,
      ) async {
        // The message alone leaves the user stuck; the suggestion is the part
        // that says which field to look at.
        await tester.pumpWidget(
          _host(
            uiStyle,
            NumberResultPanel(
              uiStyle: uiStyle,
              state: const NumberTheoryState(
                number: '12x',
                error: SymbolicFailure(
                  kind: 'parse',
                  message: 'That is not a whole number',
                  suggestion:
                      'Remove the x, or use the Matrix tool for algebra.',
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('That is not a whole number'), findsOneWidget);
        expect(
          find.text('Remove the x, or use the Matrix tool for algebra.'),
          findsOneWidget,
        );
      });
    }
  });

  group('MatrixResultPanel errors', () {
    for (final uiStyle in UiStyle.values) {
      testWidgets('shows the suggestion too ($uiStyle)', (tester) async {
        await tester.pumpWidget(
          _host(
            uiStyle,
            MatrixResultPanel(
              uiStyle: uiStyle,
              state: const MatrixState(
                cells: [
                  ['1', '2'],
                ],
                error: SymbolicFailure(
                  kind: 'parse',
                  message: 'That cell is not a number',
                  suggestion: 'Use a fraction like 3/4, not a decimal.',
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('That cell is not a number'), findsOneWidget);
        expect(
          find.text('Use a fraction like 3/4, not a decimal.'),
          findsOneWidget,
        );
      });
    }
  });

  group('history restore', () {
    // The history screen hands a snapshot to whichever workspace produced it,
    // reading the declared kind rather than guessing from the text. These check
    // each shape reaches its own workspace, without running the bridge.
    ///
    // Driven through a widget because the entry point takes a WidgetRef, the
    // same thing the history screen has.
    late WidgetRef captured;

    Future<ProviderContainer> pumpRestore(
      WidgetTester tester,
      String snapshot,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [historyProvider.overrideWith(_EmptyHistory.new)],
          child: MaterialApp(home: _RefCapture((ref) => captured = ref)),
        ),
      );
      await tester.pumpAndSettle();
      restoreSymbolicSnapshot(captured, snapshot);
      return ProviderScope.containerOf(
        tester.element(find.byType(_RefCapture)),
      );
    }

    testWidgets('a matrix snapshot reopens the grid', (tester) async {
      final c = await pumpRestore(
        tester,
        '{"kind":"matrix","cells":[["1","2"],["3","4"]]}',
      );
      addTearDown(c.dispose);

      final state = c.read(matrixProvider);
      expect(state.cells, [
        ['1', '2'],
        ['3', '4'],
      ]);
      // The analysis is deliberately not restored: it is display text, and
      // showing a stale rendering beside a restored grid would be an answer to
      // a question nobody asked.
      expect(state.analysis, isNull);
    });

    testWidgets('a number snapshot reopens the number', (tester) async {
      final c = await pumpRestore(
        tester,
        '{"kind":"number_theory","number":"360"}',
      );
      addTearDown(c.dispose);

      expect(c.read(numberTheoryProvider).number, '360');
      expect(c.read(numberTheoryProvider).analysis, isNull);
    });

    testWidgets('a snapshot with no kind still reaches the algebra workspace', (
      tester,
    ) async {
      // The original symbolic snapshots predate the kind field, so a missing
      // kind has to keep working rather than becoming a dead entry.
      final c = await pumpRestore(tester, '{"expression":"x^2"}');
      addTearDown(c.dispose);

      expect(c.read(algebraProvider).expression, 'x^2');
    });

    testWidgets('an unreadable snapshot leaves every workspace alone', (
      tester,
    ) async {
      final c = await pumpRestore(tester, 'not json at all');
      addTearDown(c.dispose);
      c.read(matrixProvider.notifier).setCells([
        ['7', '7'],
      ]);

      restoreSymbolicSnapshot(captured, 'not json at all');

      // A garbled entry must not clear a grid the user was working in.
      expect(c.read(matrixProvider).cells, [
        ['7', '7'],
      ]);
    });

    testWidgets('a matrix snapshot with a ragged grid is refused', (
      tester,
    ) async {
      final c = await pumpRestore(
        tester,
        '{"kind":"matrix","cells":[["1","2"],["3"]]}',
      );
      addTearDown(c.dispose);
      c.read(matrixProvider.notifier).setCells([
        ['7', '7'],
      ]);

      restoreSymbolicSnapshot(
        captured,
        '{"kind":"matrix","cells":[["1","2"],["3"]]}',
      );

      expect(c.read(matrixProvider).cells, [
        ['7', '7'],
      ]);
    });
  });

  group('SymbolicPrimaryAction', () {
    for (final uiStyle in UiStyle.values) {
      testWidgets('fires when enabled ($uiStyle)', (tester) async {
        var fired = 0;
        await tester.pumpWidget(
          _host(
            uiStyle,
            SymbolicPrimaryAction(
              uiStyle: uiStyle,
              label: 'Analyse',
              isBusy: false,
              isEnabled: true,
              reason: null,
              onPressed: () => fired++,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Analyse'));
        await tester.pump();
        expect(fired, 1);
      });

      testWidgets(
        'says why when disabled, rather than going inert ($uiStyle)',
        (tester) async {
          var fired = 0;
          await tester.pumpWidget(
            _host(
              uiStyle,
              SymbolicPrimaryAction(
                uiStyle: uiStyle,
                label: 'Analyse',
                isBusy: false,
                isEnabled: false,
                reason: 'Enter at least one cell',
                onPressed: () => fired++,
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('Enter at least one cell'), findsOneWidget);
          await tester.tap(find.text('Enter at least one cell'));
          await tester.pump();
          expect(fired, 0, reason: 'a disabled action must not fire');
        },
      );

      testWidgets('meets the 40dp touch target ($uiStyle)', (tester) async {
        await tester.pumpWidget(
          _host(
            uiStyle,
            SymbolicPrimaryAction(
              uiStyle: uiStyle,
              label: 'Analyse',
              isBusy: false,
              isEnabled: true,
              reason: null,
              onPressed: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.getSize(find.byType(SymbolicPrimaryAction)).height, 56);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      });

      testWidgets('shows a spinner while busy ($uiStyle)', (tester) async {
        await tester.pumpWidget(
          _host(
            uiStyle,
            SymbolicPrimaryAction(
              uiStyle: uiStyle,
              label: 'Analyse',
              isBusy: true,
              isEnabled: false,
              reason: null,
              onPressed: () {},
            ),
          ),
        );
        await tester.pump();

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });
    }
  });
}
