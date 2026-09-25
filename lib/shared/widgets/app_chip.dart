import 'package:flutter/material.dart';

import 'package:calc_flut_rs/app/theme/ui_style.dart';

/// A themed, tappable pill used for actions and options.
///
/// Extracted from the calculator keypad's scientific-mode chip row
/// (`Sci` / `Trig` / `Log` / `Mem`) so operation rows elsewhere in the app can
/// reuse that exact look in both UI styles instead of growing a fourth chip
/// implementation. The extraction is behaviour-preserving: the keypad renders
/// through this widget with identical parameters and colours.
///
/// Colours are supplied by the caller rather than derived, because the keypad
/// deliberately assigns a different container role per chip (`secondaryContainer`
/// for `Sci`, `tertiaryContainer` for `Trig`, `primaryContainer` for `Mem`).
///
/// In [UiStyle.liquidGlass] the fill is rendered translucent so the app's shared
/// gradient shows through; in [UiStyle.material] it is opaque. There is no
/// per-widget blur: the background is painted once at the app root.
class AppChip extends StatelessWidget {
  /// The active visual style, which decides whether the fill is translucent.
  final UiStyle uiStyle;

  /// The chip's text.
  final String label;

  /// Fill colour. Made translucent automatically in Liquid Glass mode.
  final Color backgroundColor;

  /// Text and icon colour. Must contrast with [backgroundColor] in both styles.
  final Color foregroundColor;

  /// Invoked on tap. Ignored while [isEnabled] is `false`.
  final VoidCallback? onTap;

  /// Optional widget shown before the label, e.g. a progress indicator.
  final Widget? leading;

  /// Optional widget shown after the label, e.g. a rotation caret.
  final Widget? trailing;

  /// Optional widget drawn on top of the chip's content.
  ///
  /// Use this for state that must not change the chip's size — a progress
  /// indicator that appears mid-computation, for instance. Because the content
  /// underneath is still laid out, revealing the overlay shifts nothing, which
  /// reserving space with a `trailing` widget would not achieve without leaving
  /// a visible gap on every chip.
  final Widget? overlay;

  /// When `false` the chip is dimmed and non-interactive.
  final bool isEnabled;

  /// Forces a minimum height, in logical pixels.
  ///
  /// Defaults to `null` so the chip is exactly as tall as its content, which is
  /// what the keypad's existing rows already lay out against. Pass a value (the
  /// app's 40dp touch-target floor) for standalone rows of new controls.
  final double? minimumHeight;

  /// Explains the chip's action. Also the accessibility label.
  final String? semanticLabel;

  const AppChip({
    super.key,
    required this.uiStyle,
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    this.onTap,
    this.leading,
    this.trailing,
    this.overlay,
    this.isEnabled = true,
    this.minimumHeight,
    this.semanticLabel,
  });

  /// The app-wide minimum touch target for a new interactive control.
  ///
  /// Matches the `SizedBox(width: 40, height: 40)` convention already used by
  /// the existing icon buttons, rather than introducing a new threshold.
  static const double minimumTouchTarget = 40.0;

  @override
  Widget build(BuildContext context) {
    final effectiveForeground = isEnabled
        ? foregroundColor
        : foregroundColor.withValues(alpha: 0.38);

    // Liquid Glass lets the app's shared background gradient read through the
    // fill; Material keeps the container role opaque.
    final fill = uiStyle == UiStyle.liquidGlass
        ? backgroundColor.withValues(alpha: 0.3)
        : backgroundColor;

    Widget content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: effectiveForeground,
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 2),
              trailing!,
            ],
          ],
        ),
      ),
    );

    if (overlay != null) {
      content = Stack(
        alignment: Alignment.center,
        children: [content, overlay!],
      );
    }

    Widget chip = Material(
      color: fill,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: isEnabled ? onTap : null,
        borderRadius: BorderRadius.circular(20),
        child: content,
      ),
    );

    if (minimumHeight != null) {
      chip = ConstrainedBox(
        constraints: BoxConstraints(minHeight: minimumHeight!),
        child: chip,
      );
    }

    if (semanticLabel != null) {
      chip = Tooltip(message: semanticLabel!, child: chip);
    }
    return chip;
  }
}
