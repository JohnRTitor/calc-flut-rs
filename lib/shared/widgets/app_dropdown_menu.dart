import 'package:flutter/material.dart';
import 'package:calc_flut_rs/app/theme/ui_style.dart';
import 'package:calc_flut_rs/shared/widgets/glass_utils.dart';

class AppDropdownMenuEntry {
  final String label;
  final VoidCallback onPressed;
  final IconData? icon;

  const AppDropdownMenuEntry({
    required this.label,
    required this.onPressed,
    this.icon,
  });
}

class AppDropdownMenu extends StatelessWidget {
  final IconData? icon;
  final String? label;
  final UiStyle uiStyle;
  final List<AppDropdownMenuEntry> entries;
  final String? tooltip;
  final bool showArrow;
  final bool isExpanded;

  const AppDropdownMenu({
    super.key,
    this.icon,
    this.label,
    required this.uiStyle,
    required this.entries,
    this.tooltip,
    this.showArrow = true,
    this.isExpanded = false,
  }) : assert(
         icon != null || label != null,
         'Must provide either an icon or a label',
       );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isGlass = uiStyle == UiStyle.liquidGlass;

    final glassCard = resolveGlassStyle(
      colorScheme,
      brightness: theme.brightness,
      role: GlassSurfaceRole.card,
    );

    List<Widget> buildMenuItems() {
      return entries.map((entry) {
        return MenuItemButton(
          style: const ButtonStyle(
            padding: WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            ),
            minimumSize: WidgetStatePropertyAll(Size(180, 48)),
          ),
          onPressed: entry.onPressed,
          leadingIcon: entry.icon != null ? Icon(entry.icon, size: 20) : null,
          child: Text(
            entry.label,
            style: isGlass ? TextStyle(color: colorScheme.onSurface) : null,
          ),
        );
      }).toList();
    }

    Widget buildTrigger(MenuController controller, Color? fgColor) {
      if (label != null) {
        return InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            if (controller.isOpen) {
              controller.close();
            } else {
              controller.open();
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 12.0,
            ),
            child: Row(
              mainAxisSize: isExpanded ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    label!,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: fgColor ?? colorScheme.onSurface,
                      fontSize: 16,
                    ),
                  ),
                ),
                if (showArrow) ...[
                  const SizedBox(width: 8),
                  Icon(
                    Icons.arrow_drop_down,
                    color: fgColor ?? colorScheme.onSurfaceVariant,
                  ),
                ],
              ],
            ),
          ),
        );
      }

      return IconButton(
        tooltip: tooltip,
        icon: Icon(
          icon,
          size: 22,
          color: fgColor ?? colorScheme.onSurfaceVariant,
        ),
        onPressed: () {
          if (controller.isOpen) {
            controller.close();
          } else {
            controller.open();
          }
        },
      );
    }

    if (isGlass) {
      return SharedSurface(
        uiStyle: uiStyle,
        glassRole: label != null
            ? GlassSurfaceRole.card
            : GlassSurfaceRole.button,
        frosted: true,
        borderRadius: BorderRadius.circular(label != null ? 16 : 24),
        child: MenuAnchor(
          style: const MenuStyle(
            backgroundColor: WidgetStatePropertyAll(Colors.transparent),
            elevation: WidgetStatePropertyAll(0),
            padding: WidgetStatePropertyAll(EdgeInsets.zero),
          ),
          builder: (context, controller, child) {
            return buildTrigger(controller, glassCard.foregroundColor);
          },
          menuChildren: [
            SharedSurface(
              uiStyle: uiStyle,
              glassRole: GlassSurfaceRole.panel,
              frosted: true,
              borderRadius: BorderRadius.circular(24),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: buildMenuItems(),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return MenuAnchor(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(
          colorScheme.surfaceContainerHigh,
        ),
        elevation: const WidgetStatePropertyAll(3),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(vertical: 8),
        ),
      ),
      builder: (context, controller, child) {
        return Container(
          decoration: label != null
              ? BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                )
              : null,
          child: buildTrigger(controller, null),
        );
      },
      menuChildren: buildMenuItems(),
    );
  }
}
