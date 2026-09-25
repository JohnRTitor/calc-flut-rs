import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:calc_flut_rs/app/theme/app_theme.dart';
import 'package:calc_flut_rs/app/theme/ui_style.dart';
import 'package:calc_flut_rs/features/history/domain/history_category.dart';
import 'package:calc_flut_rs/features/history/presentation/providers/history_provider.dart';
import 'package:calc_flut_rs/features/history/presentation/screens/history_screen.dart';
import 'package:calc_flut_rs/features/settings/presentation/providers/theme_provider.dart';
import 'package:calc_flut_rs/generated/rust/shared/history.dart';

/// Stands in for the real notifier, whose `build` reads history through the
/// Rust bridge and cannot run in a Dart-only test.
class _EmptyHistory extends History {
  @override
  Future<List<HistoryEntry>> build() async => const [];
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Widget host(Widget child) {
    return ProviderScope(
      overrides: [historyProvider.overrideWith(_EmptyHistory.new)],
      child: MaterialApp(
        theme: AppTheme.lightTheme(
          null,
          UiStyle.material,
          AppColorOption.defaultColor,
        ),
        home: child,
      ),
    );
  }

  // Regression: History is both a top level section in AppShell and a pushed
  // destination. As a section the shell already renders the title, so the
  // screen's own app bar produced a duplicated title.
  testWidgets('embedded history omits its app bar', (tester) async {
    await tester.pumpWidget(host(const HistoryScreen(embedded: true)));
    await tester.pumpAndSettle();

    expect(find.byType(AppBar), findsNothing);
  });

  testWidgets('embedded history keeps the clear action in the body', (
    tester,
  ) async {
    await tester.pumpWidget(host(const HistoryScreen(embedded: true)));
    await tester.pumpAndSettle();

    // The clear action used to live in the app bar, which the shell owns in
    // embedded mode, so it must have moved somewhere still reachable.
    expect(find.byIcon(Icons.delete_sweep_outlined), findsOneWidget);

    // Category filter must still be present.
    expect(find.text(HistoryCategory.calculator.label), findsOneWidget);
  });

  testWidgets('pushed history keeps its app bar with the clear action', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [historyProvider.overrideWith(_EmptyHistory.new)],
        child: MaterialApp(
          theme: AppTheme.lightTheme(
            null,
            UiStyle.material,
            AppColorOption.defaultColor,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const HistoryScreen(),
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    expect((appBar.title! as Text).data, 'History');
    expect(find.byType(BackButton), findsOneWidget);
    expect(find.byIcon(Icons.delete_sweep_outlined), findsOneWidget);
  });
}
