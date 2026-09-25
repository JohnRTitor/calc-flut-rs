import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:calc_flut_rs/app/theme/app_theme.dart';
import 'package:calc_flut_rs/app/theme/ui_style.dart';
import 'package:calc_flut_rs/features/settings/presentation/providers/theme_provider.dart';
import 'package:calc_flut_rs/features/settings/presentation/screens/settings_screen.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Widget host(SettingsScreen screen) {
    return ProviderScope(
      child: MaterialApp(
        theme: AppTheme.lightTheme(
          null,
          UiStyle.material,
          AppColorOption.defaultColor,
        ),
        home: screen,
      ),
    );
  }

  // Regression: Settings and History are both a top level section in AppShell
  // and a pushed destination. As a section the shell already renders the
  // title in its app bar, so the screen's own app bar produced a duplicated
  // title on screen.
  testWidgets('embedded settings omits its app bar', (tester) async {
    await tester.pumpWidget(host(const SettingsScreen(embedded: true)));
    await tester.pumpAndSettle();

    expect(find.byType(AppBar), findsNothing);
    expect(find.text('Settings'), findsNothing);
  });

  testWidgets('pushed settings keeps its app bar and back action', (
    tester,
  ) async {
    // Push it for real, otherwise there is no route to pop and Flutter
    // correctly omits the back button.
    await tester.pumpWidget(
      ProviderScope(
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
                      builder: (_) => const SettingsScreen(),
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
    expect(appBar.title, isA<Text>());
    expect((appBar.title! as Text).data, 'Settings');

    expect(
      find.byType(BackButton),
      findsOneWidget,
      reason: 'pushed settings must have a working back action',
    );
  });

  // Both must still be usable: the embedded variant is the one that is short
  // one app bar, not short one theme control.
  testWidgets('embedded settings still renders its content', (tester) async {
    tester.view.physicalSize = const Size(500, 8000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(host(const SettingsScreen(embedded: true)));
    await tester.pumpAndSettle();

    expect(find.text('System'), findsOneWidget);
    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Visual Style'), findsOneWidget);
  });
}
