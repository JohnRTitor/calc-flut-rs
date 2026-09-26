import 'package:flutter/material.dart';

import 'package:calc_flut_rs/shared/layouts/responsive_workspace_layout.dart';

/// A [ResponsiveWorkspaceLayout] shaped for a screen whose controls are a
/// keypad.
///
/// Retained as a name because three screens legitimately are keypad-shaped — the
/// loan and investment calculators, and the converter — and saying
/// "controls" there would lose the information that the keys must stay under one
/// thumb. It is a thin wrapper, not a second implementation: the
/// short-screen fallback and the pinned arrangement live in one place, so the
/// two layouts cannot drift apart the way the originals did.
class ResponsiveKeypadLayout extends StatelessWidget {
  /// The top section of the screen, usually containing results, inputs, and charts.
  final Widget displayArea;

  /// The bottom section of the screen, usually containing a numeric keypad or controls.
  final Widget keypad;

  /// The flex value for the display area when unconstrained (default: 55).
  final int displayFlex;

  /// The flex value for the keypad when unconstrained (default: 45).
  final int keypadFlex;

  /// The minimum height the keypad should maintain in constrained mode.
  /// If null, defaults to 350 for most utilities or 450 for the main calculator.
  final double? keypadMinHeight;

  const ResponsiveKeypadLayout({
    super.key,
    required this.displayArea,
    required this.keypad,
    this.displayFlex = 55,
    this.keypadFlex = 45,
    this.keypadMinHeight,
  });

  @override
  Widget build(BuildContext context) {
    return ResponsiveWorkspaceLayout(
      displayArea: displayArea,
      controls: keypad,
      pinControls: true,
      displayFlex: displayFlex,
      controlsFlex: keypadFlex,
      controlsMinHeight: keypadMinHeight ?? 350,
    );
  }
}
