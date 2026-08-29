import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:calc_flut_rs/app/theme/app_theme.dart';
import 'package:calc_flut_rs/app/theme/ui_style.dart';

import 'package:calc_flut_rs/features/settings/presentation/providers/theme_provider.dart';
import 'package:calc_flut_rs/app/navigation/main_navigation_bar.dart';
import 'package:calc_flut_rs/shared/widgets/glass_utils.dart';

import 'package:toastification/toastification.dart';

/// The root widget of the Calculator application.
///
/// It sets up the dynamic theming system, provides the global application state,
/// and handles the background rendering for the Liquid Glass visual style.
class CalculatorApp extends ConsumerWidget {
  const CalculatorApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final uiStyle = ref.watch(uiStyleProvider);
    final colorOption = ref.watch(appColorProvider);

    ThemeMode flutterThemeMode;
    switch (themeMode) {
      case AppThemeMode.light:
        flutterThemeMode = ThemeMode.light;
        break;
      case AppThemeMode.dark:
      case AppThemeMode.amoled:
        flutterThemeMode = ThemeMode.dark;
        break;
      case AppThemeMode.system:
        flutterThemeMode = ThemeMode.system;
        break;
    }

    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        final lightTheme = AppTheme.lightTheme(
          lightDynamic,
          uiStyle,
          colorOption,
        );
        final darkTheme = themeMode == AppThemeMode.amoled
            ? AppTheme.amoledTheme(darkDynamic, uiStyle, colorOption)
            : AppTheme.darkTheme(darkDynamic, uiStyle, colorOption);

        final materialApp = MaterialApp(
          title: 'Calculator',
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: flutterThemeMode,
          home: const MainScreen(),
          builder: (context, child) {
            if (uiStyle == UiStyle.liquidGlass) {
              // Resolve active theme manually because Theme.of(context) in builder
              // can return the default fallback dark theme.
              final isDark =
                  flutterThemeMode == ThemeMode.dark ||
                  (flutterThemeMode == ThemeMode.system &&
                      MediaQuery.platformBrightnessOf(context) ==
                          Brightness.dark);

              final activeTheme = isDark ? darkTheme : lightTheme;

              // Global stable background rendered once behind the navigator.
              // Every screen has transparent scaffold, so this shows through.
              return Stack(
                children: [
                  Positioned.fill(
                    child: RepaintBoundary(
                      child: SharedGlassBackground(
                        themeMode: themeMode,
                        brightness: activeTheme.brightness,
                        colorScheme: activeTheme.colorScheme,
                      ),
                    ),
                  ),
                  child ?? const SizedBox.shrink(),
                ],
              );
            }
            return child!;
          },
        );

        return ToastificationWrapper(child: materialApp);
      },
    );
  }
}
