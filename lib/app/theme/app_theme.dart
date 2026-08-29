import 'package:flutter/material.dart';
import 'package:calc_flut_rs/app/theme/ui_style.dart';
import 'package:calc_flut_rs/features/settings/presentation/providers/theme_provider.dart';
import 'package:calc_flut_rs/app/theme/app_theme_extension.dart';

/// Defines the core theme configurations and visual properties for the application.
class AppTheme {
  static const fallbackSeedColor = Colors.teal; // green-tinted aesthetic

  /// Standard button radius used across the app
  static const double buttonRadius = 28.0;

  /// Card radius for display panels and settings cards
  static const double cardRadius = 24.0;

  /// Chip radius for scientific mode toggles
  static const double chipRadius = 20.0;

  static ColorScheme _resolveColorScheme(
    Brightness brightness,
    ColorScheme? dynamicColorScheme,
    AppColorOption colorOption,
  ) {
    if (colorOption == AppColorOption.materialYou &&
        dynamicColorScheme != null) {
      return dynamicColorScheme;
    }

    Color seedColor;
    switch (colorOption) {
      case AppColorOption.blue:
        seedColor = Colors.blue;
        break;
      case AppColorOption.purple:
        seedColor = Colors.purple;
        break;
      case AppColorOption.orange:
        seedColor = Colors.orange;
        break;
      case AppColorOption.red:
        seedColor = Colors.red;
        break;
      case AppColorOption.pink:
        seedColor = Colors.pink;
        break;
      case AppColorOption.cyan:
        seedColor = Colors.cyan;
        break;
      case AppColorOption.indigo:
        seedColor = Colors.indigo;
        break;
      case AppColorOption.defaultColor:
      case AppColorOption.materialYou:
        seedColor = fallbackSeedColor;
        break;
    }

    return ColorScheme.fromSeed(seedColor: seedColor, brightness: brightness);
  }

  /// Generates the standard light theme data.
  static ThemeData lightTheme(
    ColorScheme? dynamicColorScheme,
    UiStyle uiStyle,
    AppColorOption colorOption,
  ) {
    final ColorScheme colorScheme = _resolveColorScheme(
      Brightness.light,
      dynamicColorScheme,
      colorOption,
    );

    return _buildTheme(colorScheme, uiStyle);
  }

  /// Generates the standard dark theme data.
  static ThemeData darkTheme(
    ColorScheme? dynamicColorScheme,
    UiStyle uiStyle,
    AppColorOption colorOption,
  ) {
    final ColorScheme colorScheme = _resolveColorScheme(
      Brightness.dark,
      dynamicColorScheme,
      colorOption,
    );

    return _buildTheme(colorScheme, uiStyle);
  }

  /// Generates a pitch-black theme data specifically optimized for AMOLED screens.
  static ThemeData amoledTheme(
    ColorScheme? dynamicColorScheme,
    UiStyle uiStyle,
    AppColorOption colorOption,
  ) {
    final ColorScheme baseColorScheme = _resolveColorScheme(
      Brightness.dark,
      dynamicColorScheme,
      colorOption,
    );

    // Override surface colors to pure black for AMOLED
    final ColorScheme amoledColorScheme = baseColorScheme.copyWith(
      surface: Colors.black,
      surfaceContainerLowest: Colors.black,
      surfaceContainerLow: const Color(0xFF0A0A0A),
      surfaceContainer: const Color(0xFF141414),
      surfaceContainerHigh: const Color(0xFF1E1E1E),
      surfaceContainerHighest: const Color(0xFF282828),
    );

    return _buildTheme(amoledColorScheme, uiStyle).copyWith(
      scaffoldBackgroundColor: uiStyle == UiStyle.liquidGlass
          ? Colors.transparent
          : Colors.black,
    );
  }

  static ThemeData _buildTheme(ColorScheme colorScheme, UiStyle uiStyle) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: uiStyle == UiStyle.liquidGlass
          ? Colors.transparent
          : colorScheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: uiStyle == UiStyle.liquidGlass
            ? Colors.transparent
            : null,
        elevation: 0,
        scrolledUnderElevation: uiStyle == UiStyle.liquidGlass ? 0 : null,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(buttonRadius),
          ),
          padding: EdgeInsets.zero,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(buttonRadius),
          ),
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: colorScheme.brightness == Brightness.dark
              ? colorScheme.surfaceContainerHighest
              : colorScheme.inverseSurface,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: TextStyle(
          color: colorScheme.brightness == Brightness.dark
              ? colorScheme.onSurfaceVariant
              : colorScheme.onInverseSurface,
          fontSize: 12,
        ),
      ),
      extensions: [
        AppThemeExtension(
          calculatorCard: colorScheme.surfaceContainer,
          calculatorCardBorder: colorScheme.outlineVariant,
          resultCard: colorScheme.primaryContainer,
          resultText: colorScheme.onPrimaryContainer,
          chipBackground: colorScheme.secondaryContainer,
          chipText: colorScheme.onSecondaryContainer,
        ),
      ],
    );
  }
}
