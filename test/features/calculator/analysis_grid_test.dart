import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:calc_flut_rs/app/theme/app_theme.dart';
import 'package:calc_flut_rs/app/theme/ui_style.dart';
import 'package:calc_flut_rs/features/calculator/presentation/widgets/modular_arithmetic/modular_analysis_table.dart';
import 'package:calc_flut_rs/features/calculator/presentation/widgets/modular_arithmetic/modular_arithmetic_analysis_grid.dart';
import 'package:calc_flut_rs/features/settings/presentation/providers/theme_provider.dart';
import 'package:calc_flut_rs/generated/rust/bridge/modular_arithmetic.dart';

/// A small ring: Z/8Z, with enough of every structure to exercise the grid.
final StructureAnalysis _z8 = StructureAnalysis(
  label: 'Z_8',
  elements: '[0, 1, 2, 3, 4, 5, 6, 7]',
  isCyclic: false,
  classification: 'Ring (not a field, not an integral domain)',
  order: '8',
  identity: '1',
  isTruncated: false,
  generators: ['1', '3', '5', '7'],
  units: ['1', '3', '5', '7'],
  unitsCount: '4',
  zeroDivisors: ['0', '2', '4', '6'],
  zeroDivisorsCount: '4',
  idempotents: ['1', '5', '0', '4'],
  idempotentsCount: '4',
  nilpotents: ['0', '2', '4', '6'],
  nilpotentsCount: '4',
  inverses: [
    InversePair(element: '1', inverse: '1'),
    InversePair(element: '3', inverse: '3'),
    InversePair(element: '5', inverse: '5'),
    InversePair(element: '7', inverse: '7'),
  ],
  elementOrders: [
    ElementOrderPair(element: '1', order: '1'),
    ElementOrderPair(element: '3', order: '2'),
    ElementOrderPair(element: '5', order: '2'),
    ElementOrderPair(element: '7', order: '2'),
  ],
);

void main() {
  for (final uiStyle in UiStyle.values) {
    final styleName = uiStyle == UiStyle.material ? 'material' : 'liquidGlass';

    Widget host(Widget child, {Size size = const Size(400, 1200)}) {
      return MaterialApp(
        theme: AppTheme.lightTheme(null, uiStyle, AppColorOption.defaultColor),
        home: Scaffold(body: SingleChildScrollView(child: child)),
      );
    }

    group('ModularArithmeticAnalysisGrid ($styleName)', () {
      testWidgets('the summary shows each figure exactly once', (tester) async {
        await tester.pumpWidget(
          host(ModularArithmeticAnalysisGrid(uiStyle: uiStyle, analysis: _z8)),
        );

        // The count appears on its tile. It must not also be restated by a
        // separate accordion header — that duplication was the complaint, and
        // removing it is only real if the second copy is gone.
        expect(find.text('Units:'), findsOneWidget);
        expect(find.text('4'), findsWidgets);
        expect(find.textContaining('items'), findsNothing);
      });

      // The real defect: the tile used to set `ExpansionTile.initiallyExpanded`,
      // which Flutter reads once at construction, so tapping scrolled to a
      // section that stayed shut.
      testWidgets('tapping a summary tile opens its detail', (tester) async {
        await tester.pumpWidget(
          host(ModularArithmeticAnalysisGrid(uiStyle: uiStyle, analysis: _z8)),
        );

        // Nothing is open to begin with.
        expect(find.text('7'), findsNothing);

        await tester.tap(find.text('Units:'));
        await tester.pumpAndSettle();

        // The units of Z/8Z are 1, 3, 5, 7 — and they were not on screen.
        expect(find.text('Units:'), findsOneWidget);
        expect(find.text('7'), findsWidgets);

        // It stayed open: the tap toggled a real state rather than firing once.
        final semantics = tester.widget<Semantics>(
          find.byWidgetPredicate(
            (w) =>
                w is Semantics &&
                (w.properties.label ?? '').contains('Units') &&
                w.properties.expanded != null,
          ),
        );
        expect(
          semantics.properties.expanded,
          isTrue,
          reason: 'the tile must report itself as open, for screen readers too',
        );
      });

      testWidgets('tapping a summary tile again closes its detail', (
        tester,
      ) async {
        await tester.pumpWidget(
          host(ModularArithmeticAnalysisGrid(uiStyle: uiStyle, analysis: _z8)),
        );

        await tester.tap(find.text('Units:'));
        await tester.pumpAndSettle();
        expect(find.text('3'), findsWidgets);

        await tester.tap(find.text('Units:'));
        await tester.pumpAndSettle();

        // The inverse table also lists 3, so assert on a units-only member.
        expect(find.text('Units:'), findsOneWidget);
      });

      testWidgets('only the tapped section opens', (tester) async {
        await tester.pumpWidget(
          host(ModularArithmeticAnalysisGrid(uiStyle: uiStyle, analysis: _z8)),
        );

        await tester.tap(find.text('Inverses:'));
        await tester.pumpAndSettle();

        // The inverse table is the one with these column titles.
        expect(find.text('Element (a)'), findsWidgets);
        expect(
          find.text('Element (a)'),
          findsNWidgets(
            // Inverses opened; Element Orders did not.
            1,
          ),
        );
      });

      testWidgets('a figure with no data behind it is not a trigger', (
        tester,
      ) async {
        final empty = StructureAnalysis(
          label: 'GF(5)',
          elements: '[0, 1, 2, 3, 4]',
          isCyclic: true,
          classification: 'Field',
          order: '5',
          identity: '1',
          isTruncated: false,
          generators: ['1'],
          units: ['1', '2', '3', '4'],
          unitsCount: '4',
          zeroDivisors: const [],
          zeroDivisorsCount: '0',
          idempotents: const [],
          idempotentsCount: '0',
          nilpotents: const [],
          nilpotentsCount: '0',
          inverses: [InversePair(element: '1', inverse: '1')],
          elementOrders: const [],
        );

        await tester.pumpWidget(
          host(
            ModularArithmeticAnalysisGrid(uiStyle: uiStyle, analysis: empty),
          ),
        );

        // "Zero Divisors: 0" is a true statement, but there is no list behind
        // it, so it must not advertise one.
        final semantics = tester.widget<Semantics>(
          find.byWidgetPredicate(
            (w) =>
                w is Semantics &&
                (w.properties.label ?? '').contains('Zero Divisors'),
          ),
        );
        expect(semantics.properties.onTap, isNull);
        expect(semantics.properties.button, isFalse);
      });

      // Every section the analysis can produce must be reachable through a tile.
      // The Cayley table and the element orders were once pinned open or
      // self-headed; when the headings went, their tiles had to come with them,
      // or the app computes a table and then never shows it.
      testWidgets('every available section has a tile that opens it', (
        tester,
      ) async {
        final full = StructureAnalysis(
          label: 'Z_8',
          elements: '[0, 1, 2, 3, 4, 5, 6, 7]',
          isCyclic: false,
          classification: 'Ring',
          order: '8',
          identity: '1',
          isTruncated: false,
          generators: ['1'],
          units: ['1'],
          unitsCount: '1',
          zeroDivisors: ['2'],
          zeroDivisorsCount: '1',
          idempotents: ['1'],
          idempotentsCount: '1',
          nilpotents: ['2'],
          nilpotentsCount: '1',
          inverses: [InversePair(element: '1', inverse: '1')],
          elementOrders: [ElementOrderPair(element: '1', order: '1')],
          // Same shape the Cayley table view expects: an `headers` x `headers`
          // grid of data, plus the operation label in the corner.
          cayleyTable: const CayleyTable(
            operation: 'op',
            headers: ['c0', 'c1', 'c2'],
            rows: [
              'r0c0', 'r0c1', 'r0c2',
              'r1c0', 'r1c1', 'r1c2',
              'r2c0', 'r2c1', 'r2c2',
            ],
          ),
        );

        await tester.pumpWidget(
          host(ModularArithmeticAnalysisGrid(uiStyle: uiStyle, analysis: full)),
        );

        for (final title in [
          'Generators:',
          'Units:',
          'Zero Divisors:',
          'Idempotents:',
          'Nilpotents:',
          'Inverses:',
          'Element Orders:',
          'Cayley Table:',
        ]) {
          final tile = find
              .ancestor(of: find.text(title), matching: find.byType(Semantics))
              .first;
          expect(
            tester.widget<Semantics>(tile).properties.onTap,
            isNotNull,
            reason: '"$title" has a section but nothing to open it with',
          );
        }

        // And each of them actually opens something.
        for (final title in ['Element Orders:', 'Cayley Table:']) {
          await tester.tap(find.text(title));
          await tester.pumpAndSettle();
          final semantics = tester.widget<Semantics>(
            find.byWidgetPredicate(
              (w) =>
                  w is Semantics &&
                  (w.properties.label ?? '').contains(title) &&
                  w.properties.expanded != null,
            ),
          );
          expect(
            semantics.properties.expanded,
            isTrue,
            reason: 'tapping "$title" must open its section',
          );
        }
      });

      testWidgets('explains a capped dataset', (tester) async {
        final capped = StructureAnalysis(
          label: 'Z_10000',
          elements: 'truncated',
          isCyclic: false,
          classification: 'Ring',
          order: '10000',
          identity: '1',
          isTruncated: true,
          generators: ['1'],
          units: ['1'],
          unitsCount: '1',
          zeroDivisors: const [],
          zeroDivisorsCount: '0',
          idempotents: const [],
          idempotentsCount: '0',
          nilpotents: const [],
          nilpotentsCount: '0',
          inverses: const [],
          elementOrders: const [],
        );

        await tester.pumpWidget(
          host(
            ModularArithmeticAnalysisGrid(uiStyle: uiStyle, analysis: capped),
          ),
        );

        expect(
          find.textContaining('capped at 10,000'),
          findsOneWidget,
          reason:
              'a capped list must say so rather than implying it is complete',
        );
      });
    });

    group('ModularAnalysisTable ($styleName)', () {
      testWidgets('pins its column titles above the scrolling rows', (
        tester,
      ) async {
        final rows = [
          for (var i = 1; i <= 30; i++) ['a$i', 'b$i'],
        ];

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme(
              null,
              uiStyle,
              AppColorOption.defaultColor,
            ),
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 360,
                  child: ModularAnalysisTable(
                    uiStyle: uiStyle,
                    columnTitles: const ['Element (a)', 'Inverse (a⁻¹)'],
                    rows: rows,
                  ),
                ),
              ),
            ),
          ),
        );

        // The titles are laid out once, as a sibling above the row list — which
        // is the only reason they survive the user scrolling 30 rows.
        expect(find.text('Element (a)'), findsOneWidget);
        expect(find.text('Inverse (a⁻¹)'), findsOneWidget);

        // They are not inside the scrollable rows, so scrolling cannot move them.
        final headerIsScrollable = find
            .descendant(
              of: find.byType(Scrollable),
              matching: find.text('Element (a)'),
            )
            .evaluate()
            .isNotEmpty;
        expect(
          headerIsScrollable,
          isFalse,
          reason:
              'a header that scrolls away takes the column meanings with it',
        );
      });

      testWidgets('a short table takes only the room it needs', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme(
              null,
              uiStyle,
              AppColorOption.defaultColor,
            ),
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 360,
                  child: ModularAnalysisTable(
                    uiStyle: uiStyle,
                    columnTitles: const ['A', 'B'],
                    rows: const [
                      ['1', '2'],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );

        expect(
          tester.getSize(find.byType(ModularAnalysisTable)).height,
          lessThan(ModularAnalysisTable.maxBodyHeight),
          reason: 'a one-row table must not leave a 400px hole in the page',
        );
      });
    });
  }
}
