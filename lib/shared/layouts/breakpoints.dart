import 'package:flutter/material.dart';

/// Standard screen size classifications for responsive behavior.
enum ScreenSize { compact, medium, expanded }

/// Shared metrics for layout spacing, sizing, and typography across the app.
class LayoutMetrics {
  final double buttonHeight;
  final double spacing;
  final double cardPadding;
  final double borderRadius;

  const LayoutMetrics({
    this.buttonHeight = 56.0,
    this.spacing = 16.0,
    this.cardPadding = 24.0,
    this.borderRadius = 24.0,
  });

  /// Standard default layout metrics
  static const standard = LayoutMetrics();

  /// Compact metrics for short/constrained screens
  static const compact = LayoutMetrics(
    buttonHeight: 48.0,
    spacing: 12.0,
    cardPadding: 16.0,
    borderRadius: 20.0,
  );
}

/// A set of standardised layout breakpoints and utility extensions
/// for responsive design across the app.
class AppBreakpoints {
  /// Maximum height for a screen to be considered "short".
  /// Used to determine if we need to switch from Expanded flex layouts
  /// to scrollable layouts to prevent UI compression (e.g., in split-screen or landscape).
  static const double shortScreenMaxHeight = 650.0;

  /// Maximum width for a screen to be considered "compact" (mobile portrait).
  static const double compactMaxWidth = 600.0;

  /// Minimum width for a screen to be considered "expanded" (desktop/tablet landscape).
  static const double expandedMinWidth = 840.0;
}

extension BoxConstraintsResponsiveX on BoxConstraints {
  /// Returns true if the available vertical space is less than [AppBreakpoints.shortScreenMaxHeight].
  /// This typically happens in landscape mode on phones or in split-screen mode.
  bool get isShortScreen => maxHeight < AppBreakpoints.shortScreenMaxHeight;

  /// Returns true if the available horizontal space is less than [AppBreakpoints.compactMaxWidth].
  bool get isCompactWidth => maxWidth < AppBreakpoints.compactMaxWidth;

  /// Returns true if the available horizontal space is greater than or equal to [AppBreakpoints.expandedMinWidth].
  bool get isExpandedWidth => maxWidth >= AppBreakpoints.expandedMinWidth;
}

extension BuildContextResponsiveX on BuildContext {
  /// Returns the screen size.
  Size get screenSize => MediaQuery.sizeOf(this);

  /// Whether the user has asked the platform for reduced motion.
  ///
  /// The single place the app reads that setting, so "respect the accessibility
  /// preference" cannot be implemented in some call sites and forgotten in
  /// others. Motion is not decoration here — the app's staggered entrances,
  /// scale pulses and cross-fades are the sort of thing that provokes
  /// vestibular symptoms.
  ///
  /// What to do about it depends on what the motion was for:
  ///
  /// * **decorative** — a card fading up as a page opens, a value pulsing as it
  ///   changes. Do not run it at all. Gate the animation itself.
  /// * **state-communicating** — a cross-fade showing one value became another,
  ///   an error flash. The *information* still has to arrive, so collapse the
  ///   duration with [motion] rather than dropping the animation. An instant
  ///   change communicates the same thing; a missing one does not.
  bool get prefersReducedMotion => MediaQuery.disableAnimationsOf(this);

  /// [duration], or [Duration.zero] when the user has asked for reduced motion.
  Duration motion(Duration duration) =>
      prefersReducedMotion ? Duration.zero : duration;

  /// Returns true if the screen height is less than [AppBreakpoints.shortScreenMaxHeight].
  bool get isShortScreen =>
      screenSize.height < AppBreakpoints.shortScreenMaxHeight;

  /// Returns true if the screen width is less than [AppBreakpoints.compactMaxWidth].
  bool get isCompactWidth => screenSize.width < AppBreakpoints.compactMaxWidth;

  /// Returns the standard screen size classification (compact, medium, expanded).
  ScreenSize get screenSizeClassification {
    final width = screenSize.width;
    if (width < AppBreakpoints.compactMaxWidth) {
      return ScreenSize.compact;
    } else if (width >= AppBreakpoints.expandedMinWidth) {
      return ScreenSize.expanded;
    } else {
      return ScreenSize.medium;
    }
  }
}
