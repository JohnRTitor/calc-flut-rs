import 'dart:ui';
import 'package:calc_flut_rs/app/theme/ui_style.dart';
import 'package:calc_flut_rs/features/settings/presentation/providers/theme_provider.dart';
import 'package:flutter/material.dart';

/// Lightweight Liquid Glass roles for consistent, theme-aware surfaces.
enum GlassSurfaceRole { panel, card, button, accent, primary, destructive }

/// Defines the color, border, and shadow properties for a specific glass surface.
class GlassStyle {
  final Color fillColor;
  final Color borderColor;
  final Color foregroundColor;
  final List<BoxShadow> shadows;

  const GlassStyle({
    required this.fillColor,
    required this.borderColor,
    required this.foregroundColor,
    this.shadows = const [],
  });
}

/// Provides a lightweight, flat-tint background for Liquid Glass mode.
/// Rendered once at the app root — no heavy shaders across the whole screen.
class SharedGlassBackground extends StatelessWidget {
  final AppThemeMode themeMode;
  final Brightness brightness;
  final ColorScheme colorScheme;

  const SharedGlassBackground({
    super.key,
    required this.themeMode,
    required this.brightness,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    final Color bgColor;
    final bool isDark = brightness == Brightness.dark;

    if (themeMode == AppThemeMode.amoled) {
      bgColor = Colors.black;
    } else if (isDark) {
      bgColor = Color.lerp(
        colorScheme.surface,
        colorScheme.primaryContainer,
        0.04,
      )!;
    } else {
      bgColor = Color.lerp(
        colorScheme.surface,
        colorScheme.primaryContainer,
        0.08,
      )!;
    }

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        gradient: themeMode == AppThemeMode.amoled
            ? null
            : RadialGradient(
                center: Alignment.topLeft,
                radius: 1.5,
                colors: [
                  Color.lerp(bgColor, Colors.white, isDark ? 0.04 : 0.15)!,
                  bgColor,
                  Color.lerp(bgColor, Colors.black, isDark ? 0.3 : 0.08)!,
                ],
              ),
      ),
    );
  }
}

/// Resolves the specific visual properties (`GlassStyle`) for a given surface role.
///
/// Adapts the colors and borders based on the current theme brightness, color scheme,
/// and whether the surface is currently selected/active.
GlassStyle resolveGlassStyle(
  ColorScheme colorScheme, {
  required Brightness brightness,
  GlassSurfaceRole role = GlassSurfaceRole.card,
  bool isSelected = false,
}) {
  final bool isDark = brightness == Brightness.dark;
  final Color baseSurface = isDark
      ? colorScheme.surfaceContainerHigh
      : colorScheme.surface;
  final Color raisedSurface = isDark
      ? colorScheme.surfaceContainerHighest
      : colorScheme.surfaceContainerLow;

  switch (role) {
    case GlassSurfaceRole.panel:
      return GlassStyle(
        fillColor: isDark
            ? raisedSurface.withValues(alpha: 0.4)
            : Color.lerp(
                baseSurface,
                raisedSurface,
                0.72,
              )!.withValues(alpha: 0.6),
        borderColor: isDark
            ? Colors.white.withValues(alpha: 0.12)
            : colorScheme.outlineVariant.withValues(alpha: 0.3),
        foregroundColor: colorScheme.onSurface,
      );
    case GlassSurfaceRole.card:
      return GlassStyle(
        fillColor: isDark
            ? raisedSurface.withValues(alpha: isSelected ? 0.5 : 0.3)
            : Color.lerp(
                baseSurface,
                raisedSurface,
                isSelected ? 0.88 : 0.7,
              )!.withValues(alpha: isSelected ? 0.7 : 0.5),
        borderColor: isSelected
            ? colorScheme.primary.withValues(alpha: isDark ? 0.4 : 0.4)
            : (isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : colorScheme.outlineVariant.withValues(alpha: 0.25)),
        foregroundColor: isSelected
            ? colorScheme.onPrimaryContainer
            : colorScheme.onSurface,
        shadows: isSelected
            ? [
                BoxShadow(
                  color: colorScheme.primary.withValues(
                    alpha: isDark ? 0.15 : 0.12,
                  ),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ]
            : const [],
      );
    case GlassSurfaceRole.button:
      return GlassStyle(
        fillColor: isDark
            ? colorScheme.surfaceContainerHigh.withValues(
                alpha: isSelected ? 0.5 : 0.3,
              )
            : Color.lerp(
                baseSurface,
                raisedSurface,
                isSelected ? 0.92 : 0.76,
              )!.withValues(alpha: isSelected ? 0.7 : 0.5),
        borderColor: isSelected
            ? colorScheme.primary.withValues(alpha: isDark ? 0.34 : 0.3)
            : (isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : colorScheme.outlineVariant.withValues(alpha: 0.2)),
        foregroundColor: isSelected
            ? colorScheme.primary
            : colorScheme.onSurface,
      );
    case GlassSurfaceRole.accent:
      return GlassStyle(
        fillColor: isDark
            ? colorScheme.tertiaryContainer.withValues(
                alpha: isSelected ? 0.4 : 0.25,
              )
            : Color.lerp(
                colorScheme.tertiaryContainer,
                baseSurface,
                0.18,
              )!.withValues(alpha: isSelected ? 0.6 : 0.45),
        borderColor: colorScheme.tertiary.withValues(
          alpha: isDark ? 0.32 : 0.25,
        ),
        foregroundColor: isSelected
            ? colorScheme.onTertiaryContainer
            : colorScheme.tertiary,
      );
    case GlassSurfaceRole.primary:
      return GlassStyle(
        fillColor: isDark
            ? colorScheme.primary.withValues(alpha: isSelected ? 0.35 : 0.25)
            : Color.lerp(
                colorScheme.primaryContainer,
                colorScheme.primary,
                0.18,
              )!.withValues(alpha: isSelected ? 0.7 : 0.55),
        borderColor: colorScheme.primary.withValues(alpha: isDark ? 0.4 : 0.3),
        foregroundColor: isDark
            ? colorScheme.onPrimaryContainer
            : colorScheme.onPrimaryContainer,
        shadows: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: isDark ? 0.15 : 0.12),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      );
    case GlassSurfaceRole.destructive:
      return GlassStyle(
        fillColor: isDark
            ? colorScheme.errorContainer.withValues(alpha: 0.3)
            : Color.lerp(
                colorScheme.errorContainer,
                baseSurface,
                0.2,
              )!.withValues(alpha: 0.5),
        borderColor: colorScheme.error.withValues(alpha: isDark ? 0.24 : 0.2),
        foregroundColor: isDark
            ? colorScheme.onErrorContainer
            : colorScheme.error,
      );
  }
}

/// A unified surface widget for Material You and Liquid Glass styles.
class SharedSurface extends StatelessWidget {
  final UiStyle uiStyle;
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius borderRadius;
  final Color? materialColor;
  final VoidCallback? onTap;
  final Color? glassColor;
  final bool isInteractive;
  final bool isSelected;
  final GlassSurfaceRole glassRole;
  final bool frosted;

  const SharedSurface({
    super.key,
    required this.uiStyle,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.materialColor,
    this.onTap,
    this.glassColor,
    this.isInteractive = false,
    this.isSelected = false,
    this.glassRole = GlassSurfaceRole.card,
    this.frosted = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    Widget content = child;
    if (padding != null) {
      content = Padding(padding: padding!, child: content);
    }

    if (uiStyle == UiStyle.liquidGlass) {
      final style = resolveGlassStyle(
        colorScheme,
        brightness: theme.brightness,
        role: glassRole,
        isSelected: isSelected,
      );

      final baseColor = glassColor ?? style.fillColor;

      Widget glassLayer = AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          border: Border.all(
            color: style.borderColor,
            width: isSelected ? 1.2 : 0.8,
          ),
          boxShadow: style.shadows,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.lerp(baseColor, Colors.white, isDark ? 0.08 : 0.3)!,
              baseColor,
              Color.lerp(baseColor, Colors.black, isDark ? 0.15 : 0.05)!,
            ],
            stops: const [0.0, 0.4, 1.0],
          ),
        ),
        child: ClipRRect(borderRadius: borderRadius, child: content),
      );

      if (frosted) {
        glassLayer = ClipRRect(
          borderRadius: borderRadius,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: glassLayer,
          ),
        );
      }

      if (onTap != null || isInteractive) {
        glassLayer = Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: borderRadius,
            onTap: onTap,
            child: glassLayer,
          ),
        );
      }

      if (margin != null) {
        return Padding(padding: margin!, child: glassLayer);
      }
      return glassLayer;
    }

    Widget materialLayer = Material(
      color: materialColor ?? colorScheme.surfaceContainerHighest,
      borderRadius: borderRadius,
      clipBehavior: Clip.antiAlias,
      child: onTap != null || isInteractive
          ? InkWell(onTap: onTap, child: content)
          : content,
    );

    if (margin != null) {
      return Padding(padding: margin!, child: materialLayer);
    }
    return materialLayer;
  }
}
