import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:calc_flut_rs/app/theme/app_theme.dart';
import 'package:calc_flut_rs/app/theme/ui_style.dart';
import 'package:calc_flut_rs/features/settings/presentation/providers/theme_provider.dart';
import 'package:calc_flut_rs/features/settings/presentation/screens/settings_screen.dart';

void main() {
  // Regression: the settings switches used to be wrapped in a raw Container
  // carrying a background color. The ListTile inside SwitchListTile paints its
  // selected state and ink on the nearest Material ancestor, so that
  // DecoratedBox sat between them and hid the effect:
  //   "ListTile background color or ink splashes may be invisible"
  // The shell now builds every section eagerly, so Settings is built at
  // startup and the warning fired on every hot restart.
  for (final uiStyle in UiStyle.values) {
    testWidgets(
      'settings switches render without ListTile warnings ($uiStyle)',
      (tester) async {
        SharedPreferences.setMockInitialValues({});

        // The settings body is a ListView, so the switches are only built when
        // they are within the viewport. Use a tall surface so they are actually
        // laid out, otherwise this test proves nothing.
        tester.view.physicalSize = const Size(500, 8000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: AppTheme.lightTheme(
                null,
                uiStyle,
                AppColorOption.defaultColor,
              ),
              home: const SettingsScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Guard the guard: the switches must have been built for this to mean
        // anything.
        expect(find.byType(SwitchListTile), findsWidgets);

        expect(tester.takeException(), isNull);
      },
    );
  }
}
