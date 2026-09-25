import 'package:flutter/material.dart';

/// Represents the different modules in the calculator that generate history.
///
/// The label, icon and tooltip live together on the enum so the history
/// filter's chips cannot drift out of step with the categories themselves —
/// a separately maintained tooltip list silently goes stale the moment a
/// category is added.
enum HistoryCategory {
  calculator('Calculator', Icons.calculate, 'Basic calculator history'),
  functionEvaluator(
    'Fn Evaluator',
    Icons.functions,
    'Function evaluator history',
  ),
  modularArithmetic(
    'Modular Math',
    Icons.architecture,
    'Modular arithmetic history',
  ),
  symbolic(
    'Symbolic Math',
    Icons.auto_fix_high,
    'Symbolic algebra history',
  );

  /// Short name shown on the history filter's chips.
  final String label;

  /// Icon shown on the history filter's chips.
  final IconData icon;

  /// Longer explanation shown as the chip's tooltip.
  final String tooltip;

  const HistoryCategory(this.label, this.icon, this.tooltip);
}
