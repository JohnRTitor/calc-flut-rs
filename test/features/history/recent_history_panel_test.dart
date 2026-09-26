import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:calc_flut_rs/app/theme/app_theme.dart';
import 'package:calc_flut_rs/app/theme/ui_style.dart';
import 'package:calc_flut_rs/features/history/domain/history_category.dart';
import 'package:calc_flut_rs/features/history/presentation/providers/history_provider.dart';
import 'package:calc_flut_rs/features/history/presentation/widgets/history_entry_card.dart';
import 'package:calc_flut_rs/features/history/presentation/widgets/recent_history_panel.dart';
import 'package:calc_flut_rs/features/settings/presentation/providers/theme_provider.dart';
import 'package:calc_flut_rs/generated/rust/shared/history.dart';
import 'package:calc_flut_rs/shared/layouts/breakpoints.dart';
import 'package:calc_flut_rs/shared/layouts/responsive_workspace_layout.dart';

class _OfflineHistory extends History {
  _OfflineHistory(this.entries);

  final List<HistoryEntry> entries;

  @override
  Future<List<HistoryEntry>> build() async => entries;
}

class _PinnedUiStyle extends UiStyleNotifier {
  _PinnedUiStyle(this.style);

  final UiStyle style;

  @override
  UiStyle build() => style;
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

  Widget host({
    required double width,
    required double height,
    required UiStyle uiStyle,
    required HistoryCategory category,
  }) {
    return ProviderScope(
      overrides: [
        historyProvider.overrideWith(
          () => _OfflineHistory([
            _entry('own', category.name),
            _entry('other', HistoryCategory.matrices.name),
          ]),
        ),
        uiStyleProvider.overrideWith(() => _PinnedUiStyle(uiStyle)),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme(null, uiStyle, AppColorOption.defaultColor),
        home: Scaffold(
          body: SizedBox(
            width: width,
            height: height,
            child: ResponsiveWorkspaceLayout(
              displayArea: const SizedBox(height: 100, child: Text('display')),
              controls: const SizedBox(height: 60, child: Text('controls')),
              sidePanel: RecentHistoryPanel(category: category),
            ),
          ),
        ),
      ),
    );
  }

  for (final uiStyle in UiStyle.values) {
    final styleName = uiStyle == UiStyle.material ? 'material' : 'liquidGlass';

    group('the expanded-width history panel ($styleName)', () {
      // AC-7 / IA-5: this is the one thing the app does with a desktop-class
      // window that it cannot do on a phone, so the threshold is worth pinning
      // in both directions.
      testWidgets('appears on a desktop-class window', (tester) async {
        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = const Size(1200, 800);
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          host(
            width: 1200,
            height: 800,
            uiStyle: uiStyle,
            category: HistoryCategory.algebra,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(RecentHistoryPanel), findsOneWidget);
        expect(find.byType(HistoryEntryCard), findsOneWidget);
      });

      testWidgets('is absent on a phone', (tester) async {
        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = const Size(400, 800);
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          host(
            width: 400,
            height: 800,
            uiStyle: uiStyle,
            category: HistoryCategory.algebra,
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byType(RecentHistoryPanel),
          findsNothing,
          reason: 'the width is worth more to the workspace than to a list',
        );
        // And not even a collapsed header promising one.
        expect(find.textContaining('Recent in'), findsNothing);
      });

      testWidgets('is absent at the medium breakpoint', (tester) async {
        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = const Size(720, 800);
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          host(
            width: 720,
            height: 800,
            uiStyle: uiStyle,
            category: HistoryCategory.algebra,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(RecentHistoryPanel), findsNothing);
      });

      // The panel is offered, not imposed. Above the expanded breakpoint there
      // can still be a window too narrow to spare it without squeezing the
      // workspace below a compact column, and taking 320px off a 900px window
      // would do exactly that.
      testWidgets('is withheld when it would squeeze the workspace', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = const Size(900, 800);
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          host(
            width: 900,
            height: 800,
            uiStyle: uiStyle,
            category: HistoryCategory.algebra,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(RecentHistoryPanel), findsNothing);
        expect(
          tester.getSize(find.text('display')).width,
          900.0,
          reason: 'the workspace keeps the full width it would otherwise have',
        );
      });

      testWidgets('leaves the workspace at least a compact column wide', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = const Size(1200, 800);
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          host(
            width: 1200,
            height: 800,
            uiStyle: uiStyle,
            category: HistoryCategory.algebra,
          ),
        );
        await tester.pumpAndSettle();

        final panelWidth = tester
            .getSize(find.byType(RecentHistoryPanel))
            .width;
        expect(
          tester.getSize(find.text('display')).width,
          greaterThanOrEqualTo(1200 - panelWidth - 1),
        );
        expect(
          1200 - panelWidth,
          greaterThanOrEqualTo(AppBreakpoints.compactMaxWidth),
        );
      });

      testWidgets('shows only its own tool entries', (tester) async {
        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = const Size(1200, 800);
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          host(
            width: 1200,
            height: 800,
            uiStyle: uiStyle,
            category: HistoryCategory.algebra,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('= own'), findsOneWidget);
        expect(
          find.text('= other'),
          findsNothing,
          reason:
              'the panel is this tool\'s history, not a second History '
              'section',
        );
      });

      testWidgets('collapses on request and says what the control does', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = const Size(1200, 800);
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          host(
            width: 1200,
            height: 800,
            uiStyle: uiStyle,
            category: HistoryCategory.algebra,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(HistoryEntryCard), findsOneWidget);
        // The panel is offered, not imposed.
        expect(find.text('= own'), findsOneWidget);

        await tester.tap(find.byIcon(Icons.expand_less));
        await tester.pumpAndSettle();

        expect(find.byType(HistoryEntryCard), findsNothing);
        // The header survives, so the panel can be brought back.
        expect(find.textContaining('Recent in'), findsOneWidget);
        expect(
          find.byIcon(Icons.expand_more),
          findsOneWidget,
          reason:
              'the control has to advertise the way back, not only the way out',
        );
      });

      testWidgets('says so when the tool has nothing yet', (tester) async {
        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = const Size(1200, 800);
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              historyProvider.overrideWith(() => _OfflineHistory(const [])),
              uiStyleProvider.overrideWith(() => _PinnedUiStyle(uiStyle)),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme(
                null,
                uiStyle,
                AppColorOption.defaultColor,
              ),
              home: const Scaffold(
                body: SizedBox(
                  width: 320,
                  height: 600,
                  child: RecentHistoryPanel(category: HistoryCategory.calculus),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Nothing computed here yet'), findsOneWidget);
      });
    });
  }
}
