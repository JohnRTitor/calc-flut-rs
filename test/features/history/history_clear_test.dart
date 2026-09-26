import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:calc_flut_rs/app/theme/app_theme.dart';
import 'package:calc_flut_rs/app/theme/ui_style.dart';
import 'package:calc_flut_rs/features/history/presentation/providers/history_provider.dart';
import 'package:calc_flut_rs/features/history/presentation/screens/history_screen.dart';
import 'package:calc_flut_rs/features/settings/presentation/providers/theme_provider.dart';
import 'package:calc_flut_rs/generated/rust/shared/history.dart';

/// A stand-in for the real notifier, whose `build` and every mutation go
/// through the Rust bridge. Records what it was asked to clear.
class _RecordingHistory extends History {
  _RecordingHistory(this.entries);

  final List<HistoryEntry> entries;
  final List<String> cleared = [];

  @override
  Future<List<HistoryEntry>> build() async => entries;

  @override
  Future<void> clearCategory(String category) async {
    cleared.add(category);
    entries.removeWhere((e) => e.category == category);
    state = AsyncData(List.of(entries));
  }
}

HistoryEntry _entry(String id, String category) => HistoryEntry(
  id: id,
  category: category,
  timestamp: 0,
  preview: jsonEncode({'expression': id, 'result': id}),
  snapshot: '{}',
  version: 1,
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Widget host(_RecordingHistory history) {
    return ProviderScope(
      overrides: [historyProvider.overrideWith(() => history)],
      child: MaterialApp(
        theme: AppTheme.lightTheme(
          null,
          UiStyle.material,
          AppColorOption.defaultColor,
        ),
        home: const HistoryScreen(),
      ),
    );
  }

  Future<void> confirmClear(WidgetTester tester) async {
    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();
  }

  // The regression: the clear action asked the store to drop the category names
  // this build *writes*, which is not the set of names it *holds*. Entries from
  // before the symbolic split, and entries from a tool that no longer exists,
  // were never named, so the delete reported success and the list refilled the
  // moment it refreshed.
  testWidgets(
    'clearing "All" removes every stored category, not just current ones',
    (tester) async {
      final history = _RecordingHistory([
        _entry('a', 'calculator'),
        _entry('b', 'symbolic'),
        _entry('c', 'someRemovedTool'),
      ]);

      await tester.pumpWidget(host(history));
      await tester.pumpAndSettle();

      // The default view is "All", and it shows all three.
      expect(find.text('= a'), findsOneWidget);
      expect(find.text('= b'), findsOneWidget);
      expect(find.text('= c'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.delete_sweep_outlined));
      await tester.pumpAndSettle();
      await confirmClear(tester);

      expect(
        history.cleared.toSet(),
        {'calculator', 'symbolic', 'someRemovedTool'},
        reason:
            'every name actually on disk must be cleared, or the entries survive '
            'and the list refills',
      );
      expect(history.entries, isEmpty);
      expect(find.text('No history yet'), findsOneWidget);
    },
  );

  testWidgets('clearing one group leaves the other groups alone', (
    tester,
  ) async {
    final history = _RecordingHistory([
      _entry('a', 'calculator'),
      _entry('b', 'symbolic'),
      _entry('c', 'algebra'),
    ]);

    await tester.pumpWidget(host(history));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Symbolic Math'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_sweep_outlined));
    await tester.pumpAndSettle();
    await confirmClear(tester);

    expect(
      history.cleared.toSet(),
      {'symbolic', 'algebra'},
      reason:
          'clearing Symbolic Math must not take the calculator history with it',
    );
    expect(history.entries.map((e) => e.id), ['a']);
  });

  // An entry from a tool this build no longer has is shown, and it says so
  // rather than being presented as a normal result with no explanation.
  testWidgets('shows an entry whose tool this build does not recognise', (
    tester,
  ) async {
    final history = _RecordingHistory([_entry('c', 'someRemovedTool')]);

    await tester.pumpWidget(host(history));
    await tester.pumpAndSettle();

    expect(
      find.text('= c'),
      findsOneWidget,
      reason: 'stored data that exists must be visible, not silently hidden',
    );
  });

  testWidgets('does not count unrecognised entries in a group filter', (
    tester,
  ) async {
    final history = _RecordingHistory([
      _entry('a', 'calculator'),
      _entry('c', 'someRemovedTool'),
    ]);

    await tester.pumpWidget(host(history));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Calculator'));
    await tester.pumpAndSettle();

    expect(find.text('= a'), findsOneWidget);
    expect(find.text('= c'), findsNothing);

    // And the clear dialog must only promise to remove the one it will remove.
    await tester.tap(find.byIcon(Icons.delete_sweep_outlined));
    await tester.pumpAndSettle();

    // The dialog composes its wording from several spans, so it is a RichText
    // rather than a Text, and it has to be read as plain text. Matched across
    // every RichText rather than by position, because the dialog's own buttons
    // are RichTexts too and their order in the tree is not the reading order.
    final wordings = tester
        .widgetList<RichText>(find.byType(RichText))
        .map((r) => r.text.toPlainText())
        .toList();

    expect(
      wordings,
      contains(contains('1 saved calculation')),
      reason:
          "the count is the user's only warning of what is about to go, and "
          'it must match what is actually removed',
    );
    expect(wordings.join(' '), isNot(contains('2 saved calculation')));
  });
}
