import 'package:flutter/material.dart';

/// Centralized theme extension for specific component colors across the application.
class AppThemeExtension extends ThemeExtension<AppThemeExtension> {
  /// Background color for standard calculator cards (like inputs).
  final Color calculatorCard;

  /// Border color for standard calculator cards.
  final Color calculatorCardBorder;

  /// Background color for result cards (Loan/EMI, Function Evaluator).
  final Color resultCard;

  /// Text color for result cards, guaranteeing contrast against [resultCard].
  final Color resultText;

  /// Background color for variable chips.
  final Color chipBackground;

  /// Text color for variable chips.
  final Color chipText;

  /// Text color for a refused request that is not the user's mistake.
  ///
  /// Distinct from `colorScheme.error`, which means "this input was wrong". A
  /// symbolic expression refused for being too large, or for having no
  /// supported form, is a different situation: the mathematics may be perfectly
  /// valid and the answer simply is not something this tool can produce. The
  /// user needs to hear "try something smaller", not "check your syntax", so
  /// the two must not share a colour.
  final Color limitationText;

  /// Background color for a limitation notice.
  final Color limitationContainer;

  const AppThemeExtension({
    required this.calculatorCard,
    required this.calculatorCardBorder,
    required this.resultCard,
    required this.resultText,
    required this.chipBackground,
    required this.chipText,
    required this.limitationText,
    required this.limitationContainer,
  });

  @override
  ThemeExtension<AppThemeExtension> copyWith({
    Color? calculatorCard,
    Color? calculatorCardBorder,
    Color? resultCard,
    Color? resultText,
    Color? chipBackground,
    Color? chipText,
    Color? limitationText,
    Color? limitationContainer,
  }) {
    return AppThemeExtension(
      calculatorCard: calculatorCard ?? this.calculatorCard,
      calculatorCardBorder: calculatorCardBorder ?? this.calculatorCardBorder,
      resultCard: resultCard ?? this.resultCard,
      resultText: resultText ?? this.resultText,
      chipBackground: chipBackground ?? this.chipBackground,
      chipText: chipText ?? this.chipText,
      limitationText: limitationText ?? this.limitationText,
      limitationContainer: limitationContainer ?? this.limitationContainer,
    );
  }

  @override
  ThemeExtension<AppThemeExtension> lerp(
    covariant ThemeExtension<AppThemeExtension>? other,
    double t,
  ) {
    if (other is! AppThemeExtension) return this;
    return AppThemeExtension(
      calculatorCard: Color.lerp(calculatorCard, other.calculatorCard, t)!,
      calculatorCardBorder: Color.lerp(
        calculatorCardBorder,
        other.calculatorCardBorder,
        t,
      )!,
      resultCard: Color.lerp(resultCard, other.resultCard, t)!,
      resultText: Color.lerp(resultText, other.resultText, t)!,
      chipBackground: Color.lerp(chipBackground, other.chipBackground, t)!,
      chipText: Color.lerp(chipText, other.chipText, t)!,
      limitationText: Color.lerp(limitationText, other.limitationText, t)!,
      limitationContainer: Color.lerp(
        limitationContainer,
        other.limitationContainer,
        t,
      )!,
    );
  }
}
