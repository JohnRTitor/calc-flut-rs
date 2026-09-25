import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:calc_flut_rs/app/theme/ui_style.dart';
import 'package:calc_flut_rs/shared/widgets/glass_utils.dart';

/// A single card in an [AppHubGrid].
@immutable
class AppHubGridItem {
  final String id;
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const AppHubGridItem({
    required this.id,
    required this.label,
    required this.icon,
    required this.onTap,
  });
}

/// The "Hub Grid" navigation pattern.
///
/// Renders a responsive grid of [SharedSurface] cards that push a dedicated
/// screen. Use it for a section holding five or more loosely related tools, or
/// a tool family that keeps growing. For two to four tightly coupled modes
/// sharing one layout, prefer `PillSwitcher` / `MultiPillSwitcher` instead.
///
/// Sections populate [items] from `appSections` in `tool_registry.dart` so a new
/// tool is a registry edit rather than a new grid-building block.
class AppHubGrid extends StatelessWidget {
  final UiStyle uiStyle;
  final List<AppHubGridItem> items;

  /// Plays a staggered fade/slide-in as cards mount. Disable for a completely
  /// static grid.
  final bool animateItems;

  const AppHubGrid({
    super.key,
    required this.uiStyle,
    required this.items,
    this.animateItems = false,
  });

  /// Smallest window in which a card can be shown without overflowing.
  static const double _minimumExtent = 96.0;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Scaffold(
        body: Center(
          child: Text(
            'No tools available yet.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    final colorScheme = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;

          // A viewport cannot lay out with a non-positive cross-axis extent:
          // SliverGridDelegateWithMaxCrossAxisExtent asserts
          // `crossAxisExtent > 0.0`. The shell hosts every section root inside
          // an IndexedStack, and those roots are built during the very first
          // frame, when the window can still measure zero (notably on Android
          // while insets settle). Below [_minimumExtent] there is also too
          // little room for a card, which would overflow the tile. Render
          // nothing until there is real space instead of asserting or
          // overflowing.
          if (!width.isFinite ||
              !height.isFinite ||
              width < _minimumExtent ||
              height < _minimumExtent) {
            return const SizedBox.shrink();
          }

          // Never let the gutters consume the whole available width, which
          // would otherwise drive the grid's cross-axis extent to zero.
          final horizontalPadding = math.min(24.0, width / 4);

          return GridView.builder(
            padding: EdgeInsets.only(
              left: horizontalPadding,
              right: horizontalPadding,
              top: 24.0,
              bottom: 24.0 + bottomInset,
            ),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 150.0,
              crossAxisSpacing: 16.0,
              mainAxisSpacing: 24.0,
              childAspectRatio: 0.8,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];

              final card = SharedSurface(
                uiStyle: uiStyle,
                onTap: item.onTap,
                borderRadius: BorderRadius.circular(24.0),
                isInteractive: true,
                glassRole: GlassSurfaceRole.card,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: uiStyle == UiStyle.liquidGlass
                            ? colorScheme.primaryContainer.withValues(
                                alpha: 0.12,
                              )
                            : colorScheme.surfaceContainerHighest,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        item.icon,
                        size: 32,
                        color: uiStyle == UiStyle.liquidGlass
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8.0),
                    Text(
                      item.label,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              );

              if (!animateItems) return card;

              return card
                  .animate()
                  .fade(duration: 400.ms, delay: (index * 50).ms)
                  .slideY(
                    begin: 0.2,
                    end: 0,
                    duration: 400.ms,
                    curve: Curves.easeOutQuart,
                  );
            },
          );
        },
      ),
    );
  }
}
