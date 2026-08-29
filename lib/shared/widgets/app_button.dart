import 'package:calc_flut_rs/shared/widgets/glass_utils.dart';
import 'package:calc_flut_rs/app/theme/ui_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Defines the functional category of a calculator button, which dictates its default
/// visual style and behavior.
enum ButtonType {
  number,
  operator,
  action,
  clear,
  equals,
  scientific,
  backspace,
}

/// A customizable button widget used throughout the calculator keypad.
///
/// Handles both Material and Liquid Glass UI styles internally. Features a scale-down
/// animation on press and a shake animation if the assigned action fails.
class AppCalcButton extends StatefulWidget {
  final String text;
  final bool Function()? onPressed;
  final VoidCallback? onLongPress;
  final ButtonType type;
  final Widget? icon;
  final bool isActive;
  final UiStyle uiStyle;

  const AppCalcButton({
    super.key,
    required this.text,
    this.onPressed,
    this.onLongPress,
    this.type = ButtonType.number,
    this.icon,
    this.isActive = false,
    required this.uiStyle,
  });

  @override
  State<AppCalcButton> createState() => _AppCalcButtonState();
}

class _AppCalcButtonState extends State<AppCalcButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _shakeController;
  double _scale = 1.0;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _handlePressDown() {
    setState(
      () => _scale = widget.uiStyle == UiStyle.liquidGlass ? 0.97 : 0.94,
    );
  }

  void _handlePressUp() {
    setState(() => _scale = 1.0);
  }

  void _handlePress() {
    if (widget.onPressed == null) return;
    if (_shakeController.isAnimating) return;

    final success = widget.onPressed!();
    if (!success && mounted) {
      HapticFeedback.vibrate();
      _shakeController.forward(from: 0.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isGlass = widget.uiStyle == UiStyle.liquidGlass;

    Widget buttonChild;

    if (isGlass) {
      final style = _resolveGlassStyle(colorScheme, theme.brightness);
      final label = IconTheme(
        data: IconThemeData(color: style.foregroundColor),
        child:
            widget.icon ??
            Text(
              widget.text,
              style: TextStyle(
                fontSize: style.fontSize,
                fontWeight: style.fontWeight,
                color: style.foregroundColor,
              ),
            ),
      );

      buttonChild = GestureDetector(
        onTapDown: (_) => _handlePressDown(),
        onTapUp: (_) => _handlePressUp(),
        onTapCancel: _handlePressUp,
        onLongPress: widget.onLongPress,
        child: SharedSurface(
          uiStyle: widget.uiStyle,
          onTap: widget.onPressed == null ? null : _handlePress,
          isInteractive: true,
          isSelected: widget.isActive,
          glassRole: style.role,
          frosted:
              style.role == GlassSurfaceRole.primary ||
              style.role == GlassSurfaceRole.destructive ||
              widget.isActive,
          borderRadius: BorderRadius.circular(28),
          child: Center(child: label),
        ),
      );
    } else {
      final (bg, fg, fontSize, fontWeight) = _getMaterialStyle(colorScheme);
      final label =
          widget.icon ??
          Text(
            widget.text,
            style: TextStyle(fontSize: fontSize, fontWeight: fontWeight),
          );

      buttonChild = GestureDetector(
        onTapDown: (_) => _handlePressDown(),
        onTapUp: (_) => _handlePressUp(),
        onTapCancel: _handlePressUp,
        onLongPress: widget.onLongPress,
        child: FilledButton(
          onPressed: widget.onPressed == null ? null : _handlePress,
          style: FilledButton.styleFrom(
            backgroundColor: bg,
            foregroundColor: fg,
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
            elevation: 0,
          ),
          child: label,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 6.0),
      child:
          AnimatedScale(
                scale: _scale,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutBack,
                child: SizedBox.expand(child: buttonChild),
              )
              .animate(controller: _shakeController, autoPlay: false)
              .shakeX(hz: 4, amount: 4),
    );
  }

  _GlassButtonStyle _resolveGlassStyle(ColorScheme cs, Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;

    if (widget.isActive) {
      return _GlassButtonStyle(
        role: GlassSurfaceRole.primary,
        foregroundColor: cs.onPrimaryContainer,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      );
    }

    switch (widget.type) {
      case ButtonType.number:
        return _GlassButtonStyle(
          role: GlassSurfaceRole.button,
          foregroundColor: cs.onSurface,
          fontSize: 26,
          fontWeight: FontWeight.w500,
        );
      case ButtonType.operator:
        return _GlassButtonStyle(
          role: GlassSurfaceRole.primary,
          foregroundColor: cs.onPrimaryContainer,
          fontSize: widget.text == 'mod' ? 18 : 24,
          fontWeight: FontWeight.w700,
        );
      case ButtonType.action:
      case ButtonType.scientific:
        return _GlassButtonStyle(
          role: GlassSurfaceRole.accent,
          foregroundColor: widget.isActive
              ? cs.onTertiaryContainer
              : (isDark ? cs.onTertiaryContainer : cs.tertiary),
          fontSize: 20,
          fontWeight: FontWeight.w600,
        );
      case ButtonType.clear:
        return _GlassButtonStyle(
          role: GlassSurfaceRole.destructive,
          foregroundColor: cs.onErrorContainer,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        );
      case ButtonType.backspace:
        return _GlassButtonStyle(
          role: GlassSurfaceRole.accent,
          foregroundColor: isDark ? cs.onTertiaryContainer : cs.tertiary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        );
      case ButtonType.equals:
        return _GlassButtonStyle(
          role: GlassSurfaceRole.primary,
          foregroundColor: cs.onPrimaryContainer,
          fontSize: 30,
          fontWeight: FontWeight.bold,
        );
    }
  }

  (Color bg, Color fg, double fontSize, FontWeight fontWeight)
  _getMaterialStyle(ColorScheme cs) {
    if (widget.isActive) {
      return (
        cs.tertiaryContainer,
        cs.onTertiaryContainer,
        18.0,
        FontWeight.w600,
      );
    }

    switch (widget.type) {
      case ButtonType.number:
        return (cs.surfaceContainerLow, cs.onSurface, 26.0, FontWeight.w500);
      case ButtonType.operator:
        return (cs.primary, cs.onPrimary, 24.0, FontWeight.w600);
      case ButtonType.action:
      case ButtonType.scientific:
        return (
          cs.surfaceContainerHigh,
          cs.onSurfaceVariant,
          20.0,
          FontWeight.w500,
        );
      case ButtonType.clear:
        return (cs.errorContainer, cs.onErrorContainer, 20.0, FontWeight.w700);
      case ButtonType.backspace:
        return (
          cs.tertiaryContainer,
          cs.onTertiaryContainer,
          20.0,
          FontWeight.w500,
        );
      case ButtonType.equals:
        return (cs.primary, cs.onPrimary, 30.0, FontWeight.bold);
    }
  }
}

class _GlassButtonStyle {
  final GlassSurfaceRole role;
  final Color foregroundColor;
  final double fontSize;
  final FontWeight fontWeight;

  const _GlassButtonStyle({
    required this.role,
    required this.foregroundColor,
    required this.fontSize,
    required this.fontWeight,
  });
}
