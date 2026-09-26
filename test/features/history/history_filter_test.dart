import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:calc_flut_rs/app/theme/app_theme.dart';
import 'package:calc_flut_rs/app/theme/ui_style.dart';
import 'package:calc_flut_rs/features/history/domain/history_category.dart';
import 'package:calc_flut_rs/features/history/presentation/widgets/history_filter_bar.dart';
import 'package:calc_flut_rs/features/settings/presentation/providers/theme_provider.dart';
import 'package:calc_flut_rs/shared/widgets/app_chip.dart';

void main() {
  group('the category model', () {
    test('gives every tool its own category', () {
      // The bug this replaces: five independent symbolic tools shared one
      // `symbolic` bucket, so a Calculus entry and a Matrices entry were
      // indistinguishable in the filter.
      expect(HistoryCategory.values.map((c) => c.name).toSet(), {
        'calculator',
        'functionEvaluator',
        'modularArithmetic',
        'algebra',
        'equationSolver',
        'calculus',
        'matrices',
        'numberTheory',
      });
    });

    test('groups the tools the way the navigation does', () {
      expect(
        HistoryGroup.calculator.categories,
        containsAll(<HistoryCategory>[
          HistoryCategory.calculator,
          HistoryCategory.functionEvaluator,
        ]),
      );
      expect(HistoryGroup.modularArithmetic.categories, <HistoryCategory>[
        HistoryCategory.modularArithmetic,
      ]);
      expect(
        HistoryGroup.symbolic.categories,
        containsAll(<HistoryCategory>[
          HistoryCategory.algebra,
          HistoryCategory.equationSolver,
          HistoryCategory.calculus,
          HistoryCategory.matrices,
          HistoryCategory.numberTheory,
        ]),
      );
    });

    test('spans all three top level groups', () {
      expect(
        HistoryCategory.values.map((c) => c.group).toSet(),
        HistoryGroup.values.toSet(),
      );
    });

    // A group holding one tool needs no second row; a group holding several
    // does, or its tools are unreachable as filters.
    test('only multi-tool groups ask for a tool row', () {
      expect(HistoryGroup.calculator.hasMultipleTools, isTrue);
      expect(HistoryGroup.symbolic.hasMultipleTools, isTrue);
      expect(HistoryGroup.modularArithmetic.hasMultipleTools, isFalse);
    });

    // Splitting the symbolic bucket must not orphan entries already on disk
    // under the old shared name.
    test('reads pre-split symbolic entries', () {
      expect(
        historyEntryMatches('symbolic', group: HistoryGroup.symbolic),
        isTrue,
      );
      expect(
        historyEntryMatches('symbolic', group: HistoryGroup.calculator),
        isFalse,
      );
      expect(
        historyEntryMatches('symbolic', category: HistoryCategory.algebra),
        isTrue,
        reason:
            'a legacy entry has no single tool, so every tool in the group '
            'should still be able to claim it',
      );
    });

    // An entry stored under a category this build does not recognise — a tool
    // that has since been removed — used to be filtered out of every view,
    // including "All". It could then be neither read nor deleted: invisible in
    // the UI while still on disk, and still counted in the clear dialog.
    test('"All" shows an entry whose category this build does not know', () {
      expect(
        historyEntryMatches('someRemovedTool'),
        isTrue,
        reason: 'hidden stored data is lost data',
      );
      // But a group filter has no such obligation, and including it there would
      // misattribute it.
      expect(
        historyEntryMatches('someRemovedTool', group: HistoryGroup.calculator),
        isFalse,
      );
      expect(
        historyEntryMatches(
          'someRemovedTool',
          category: HistoryCategory.calculator,
        ),
        isFalse,
      );
    });

    test('the "All" view still covers the current tools', () {
      for (final category in HistoryCategory.values) {
        expect(
          historyEntryMatches(category.name),
          isTrue,
          reason: '${category.name} must appear in the All view',
        );
      }
      expect(historyEntryMatches('symbolic'), isTrue);
    });

    test('resolves the covered tools for each selection', () {
      expect(
        historyCategoriesFor(group: null, category: null),
        HistoryCategory.values.toSet(),
      );
      expect(
        historyCategoriesFor(
          group: HistoryGroup.modularArithmetic,
          category: null,
        ),
        <HistoryCategory>{HistoryCategory.modularArithmetic},
      );
      expect(
        historyCategoriesFor(
          group: HistoryGroup.symbolic,
          category: HistoryCategory.matrices,
        ),
        <HistoryCategory>{HistoryCategory.matrices},
      );
    });
  });

  group('HistoryFilterBar', () {
    for (final uiStyle in UiStyle.values) {
      final styleName = uiStyle == UiStyle.material
          ? 'material'
          : 'liquidGlass';

      Widget host(
        Widget child, {
        double width = 360,
        HistoryGroup? selectedGroup,
        HistoryCategory? selectedCategory,
      }) {
        return MaterialApp(
          theme: AppTheme.lightTheme(
            null,
            uiStyle,
            AppColorOption.defaultColor,
          ),
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: width,
                child: HistoryFilterBar(
                  uiStyle: uiStyle,
                  selectedGroup: selectedGroup,
                  selectedCategory: selectedCategory,
                  onGroupChanged: (_) {},
                  onToolChanged: (_) {},
                ),
              ),
            ),
          ),
        );
      }

      group('($styleName)', () {
        // The reported failure: a single switcher of every category
        // ellipsised "Calc...", "Fn Ev...", "Symb..." on a phone-width screen,
        // with no history in it at all. Four group labels plus "All" must not
        // repeat that.
        testWidgets('shows every group label in full at 360dp', (tester) async {
          await tester.pumpWidget(host(const SizedBox.shrink()));
          await tester.pumpAndSettle();

          final groupRow = find.byKey(const ValueKey('history_group_row'));
          for (final label in [
            'All',
            ...HistoryGroup.values.map((g) => g.label),
          ]) {
            await tester.dragUntilVisible(
              find.descendant(of: groupRow, matching: find.text(label)),
              groupRow,
              const Offset(-120, 0),
            );
            expect(
              find.descendant(of: groupRow, matching: find.text(label)),
              findsOneWidget,
              reason:
                  '"$label" must be reachable in full, never as an ellipsis',
            );
          }
        });

        testWidgets('ellipsises no chip label', (tester) async {
          await tester.pumpWidget(host(const SizedBox.shrink()));
          await tester.pumpAndSettle();

          final ellipsised = tester
              .widgetList<Text>(find.byType(Text))
              .where((t) => t.overflow == TextOverflow.ellipsis)
              .map((t) => t.data);
          expect(ellipsised, isEmpty);
        });

        // A squeezed chip is an unreadable chip. Each must be laid out at its
        // own intrinsic width, which is what the scrolling row buys.
        testWidgets('lays each chip out at its natural width', (tester) async {
          await tester.pumpWidget(host(const SizedBox.shrink()));
          await tester.pumpAndSettle();

          for (final element in find.byType(AppChip).evaluate()) {
            final chip = element.widget as AppChip;
            final finder = find.byWidget(chip);
            final chipWidth = tester.getSize(finder).width;
            final text = tester.widget<Text>(
              find.descendant(of: finder, matching: find.byType(Text)),
            );
            final painter = TextPainter(
              text: TextSpan(text: text.data, style: text.style),
              textDirection: TextDirection.ltr,
            )..layout();
            expect(
              chipWidth,
              greaterThanOrEqualTo(painter.width),
              reason: 'the chip for "${text.data}" was compressed',
            );
          }
        });

        testWidgets('meets the 48dp touch-target floor', (tester) async {
          await tester.pumpWidget(
            host(const SizedBox.shrink(), selectedGroup: HistoryGroup.symbolic),
          );
          await tester.pumpAndSettle();

          final chips = find.byType(AppChip);
          expect(chips, findsWidgets);
          for (final element in chips.evaluate()) {
            expect(
              tester.getSize(find.byWidget(element.widget)).height,
              greaterThanOrEqualTo(48.0),
              reason:
                  'a filter chip is a primary control, not a dense keypad key',
            );
          }
        });

        testWidgets('shows a tool row for a multi-tool group', (tester) async {
          await tester.pumpWidget(
            host(const SizedBox.shrink(), selectedGroup: HistoryGroup.symbolic),
          );
          await tester.pumpAndSettle();

          expect(find.text('Algebra'), findsOneWidget);
        });

        testWidgets('shows no tool row for a single-tool group', (
          tester,
        ) async {
          await tester.pumpWidget(
            host(
              const SizedBox.shrink(),
              selectedGroup: HistoryGroup.modularArithmetic,
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('Modular Math'), findsOneWidget);
          // The one tool in the group is already the group's own filter, so a
          // row repeating it would be pure chrome.
          expect(
            find.descendant(
              of: find.byType(HistoryFilterBar),
              matching: find.byType(ListView),
            ),
            findsOneWidget,
          );
        });

        testWidgets('hides the tool row once a tool is chosen', (tester) async {
          await tester.pumpWidget(
            host(
              const SizedBox.shrink(),
              selectedGroup: HistoryGroup.symbolic,
              selectedCategory: HistoryCategory.calculus,
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('Algebra'), findsNothing);
        });

        // Acceptance: every tool must be reachable as its own filter.
        testWidgets('every tool in a group is reachable', (tester) async {
          for (final group in HistoryGroup.values.where(
            (g) => g.hasMultipleTools,
          )) {
            await tester.pumpWidget(
              host(const SizedBox.shrink(), selectedGroup: group),
            );
            await tester.pumpAndSettle();

            final toolRow = find.byKey(const ValueKey('history_tool_row'));
            expect(toolRow, findsOneWidget);
            for (final tool in group.categories) {
              await tester.dragUntilVisible(
                find.descendant(of: toolRow, matching: find.text(tool.label)),
                toolRow,
                const Offset(-120, 0),
              );
              expect(
                find.descendant(of: toolRow, matching: find.text(tool.label)),
                findsOneWidget,
                reason: '${tool.label} must be its own filter',
              );
            }
          }
        });
      });
    }
  });
}
