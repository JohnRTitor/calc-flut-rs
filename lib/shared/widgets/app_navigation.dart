import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:calc_flut_rs/app/theme/ui_style.dart';
import 'package:calc_flut_rs/shared/widgets/glass_utils.dart';

/// A top level navigation destination rendered by [AppNavigationDrawer] and
/// [AppNavigationRail].
///
/// Deliberately decoupled from any registry type so `lib/shared/` never depends
/// on `lib/app/`; the shell maps its own sections onto this model.
@immutable
class AppNavDestination {
  final String id;
  final String label;
  final IconData icon;

  const AppNavDestination({
    required this.id,
    required this.label,
    required this.icon,
  });
}

/// Resolves the fill for a full-screen overlay surface (drawer, navigation
/// rail, tool search).
///
/// [GlassSurfaceRole.panel] is tuned for small floating panels (dialogs,
/// notices) and is far too translucent to sit over page content. A full-screen
/// surface needs a near-opaque base: combined with the [SharedSurface.frosted]
/// blur this keeps labels legible while still reading as a glass surface.
Color resolveOverlaySurfaceFill(ColorScheme colorScheme) {
  return colorScheme.surface.withValues(alpha: 0.94);
}

/// A single selectable row used by both the drawer and the rail.
///
/// Renders through [SharedSurface] so selection looks identical in
/// `UiStyle.material` and `UiStyle.liquidGlass`, and stays keyboard and
/// screen-reader operable.
class AppNavigationTile extends StatelessWidget {
  final UiStyle uiStyle;
  final AppNavDestination destination;
  final bool isSelected;
  final bool showLabel;
  final VoidCallback onTap;

  const AppNavigationTile({
    super.key,
    required this.uiStyle,
    required this.destination,
    required this.isSelected,
    required this.onTap,
    this.showLabel = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isGlass = uiStyle == UiStyle.liquidGlass;

    final glassStyle = resolveGlassStyle(
      colorScheme,
      brightness: theme.brightness,
      role: isSelected ? GlassSurfaceRole.primary : GlassSurfaceRole.button,
      isSelected: isSelected,
    );

    final Color foreground = isGlass
        ? glassStyle.foregroundColor
        : isSelected
        ? colorScheme.onPrimaryContainer
        : colorScheme.onSurfaceVariant;

    final Widget content = showLabel
        ? Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Icon(destination.icon, size: 22, color: foreground),
              const SizedBox(width: 16),
              Flexible(
                child: Text(
                  destination.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: foreground,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          )
        : Icon(destination.icon, size: 22, color: foreground);

    final Widget surface = SharedSurface(
      uiStyle: uiStyle,
      glassRole: isSelected
          ? GlassSurfaceRole.primary
          : GlassSurfaceRole.button,
      isSelected: isSelected,
      materialColor: isSelected
          ? colorScheme.primaryContainer
          : colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(showLabel ? 16 : 24),
      onTap: onTap,
      padding: EdgeInsets.symmetric(
        horizontal: showLabel ? 12 : 0,
        vertical: 10,
      ),
      child: showLabel ? content : Center(child: content),
    );

    return Semantics(
      container: true,
      button: true,
      selected: isSelected,
      label: destination.label,
      child: Focus(
        onKeyEvent: (node, event) {
          final isActivateKey =
              event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.space ||
              event.logicalKey == LogicalKeyboardKey.numpadEnter;
          if (event is KeyDownEvent && isActivateKey) {
            onTap();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: showLabel
            ? surface
            : Tooltip(message: destination.label, child: surface),
      ),
    );
  }
}

/// Modal drawer used below the compact breakpoint (< 600 logical pixels).
///
/// A compact-width app bar exposes a hamburger button that opens this drawer;
/// it closes as soon as a destination is chosen.
class AppNavigationDrawer extends StatelessWidget {
  final UiStyle uiStyle;
  final List<AppNavDestination> destinations;
  final String selectedId;
  final ValueChanged<String> onSelected;
  final VoidCallback? onSearch;

  const AppNavigationDrawer({
    super.key,
    required this.uiStyle,
    required this.destinations,
    required this.selectedId,
    required this.onSelected,
    this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.transparent,
      child: SharedSurface(
        uiStyle: uiStyle,
        glassRole: GlassSurfaceRole.panel,
        glassColor: resolveOverlaySurfaceFill(Theme.of(context).colorScheme),
        frosted: true,
        borderRadius: BorderRadius.zero,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (onSearch != null) _buildSearchEntry(context),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  itemCount: destinations.length,
                  itemBuilder: (context, index) {
                    final destination = destinations[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: AppNavigationTile(
                        uiStyle: uiStyle,
                        destination: destination,
                        isSelected: destination.id == selectedId,
                        onTap: () => onSelected(destination.id),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchEntry(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Tooltip(
        message: 'Search tools',
        child: SharedSurface(
          uiStyle: uiStyle,
          glassRole: GlassSurfaceRole.button,
          materialColor: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          onTap: onSearch,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(Icons.search, size: 22, color: colorScheme.onSurfaceVariant),
              const SizedBox(width: 16),
              Text(
                'Search tools',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Vertical navigation rail used at the medium (600-840) and expanded (> 840)
/// breakpoints.
///
/// [extended] shows labels next to the icons on wide layouts; icon-only keeps
/// the rail compact on tablets and small desktop windows.
class AppNavigationRail extends StatelessWidget {
  final UiStyle uiStyle;
  final List<AppNavDestination> destinations;
  final String selectedId;
  final ValueChanged<String> onSelected;
  final bool extended;
  final VoidCallback? onSearch;

  const AppNavigationRail({
    super.key,
    required this.uiStyle,
    required this.destinations,
    required this.selectedId,
    required this.onSelected,
    this.extended = false,
    this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    final List<Widget> tiles = [
      if (onSearch != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: AppNavigationTile(
            uiStyle: uiStyle,
            destination: const AppNavDestination(
              id: '__search__',
              label: 'Search',
              icon: Icons.search,
            ),
            isSelected: false,
            showLabel: extended,
            onTap: onSearch!,
          ),
        ),
      ...destinations.map(
        (destination) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: AppNavigationTile(
            uiStyle: uiStyle,
            destination: destination,
            isSelected: destination.id == selectedId,
            showLabel: extended,
            onTap: () => onSelected(destination.id),
          ),
        ),
      ),
    ];

    return SharedSurface(
      uiStyle: uiStyle,
      glassRole: GlassSurfaceRole.panel,
      glassColor: resolveOverlaySurfaceFill(Theme.of(context).colorScheme),
      frosted: true,
      borderRadius: BorderRadius.zero,
      child: SafeArea(
        right: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: extended ? 12 : 10,
            vertical: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final tile in tiles)
                ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: extended ? 0 : 48,
                    minWidth: extended ? 0 : 48,
                  ),
                  child: tile,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
