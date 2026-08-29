import 'package:flutter/material.dart';
import 'package:calc_flut_rs/app/theme/ui_style.dart';
import 'package:calc_flut_rs/shared/widgets/glass_utils.dart';

class AppTabBar extends StatelessWidget {
  final TabController controller;
  final List<Tab> tabs;
  final UiStyle uiStyle;
  final double width;
  final double height;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;

  const AppTabBar({
    super.key,
    required this.controller,
    required this.tabs,
    required this.uiStyle,
    this.width = 240,
    this.height = 36,
    this.padding = const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
    this.borderRadius = const BorderRadius.all(Radius.circular(24)),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final brightness = theme.brightness;
    final isGlass = uiStyle == UiStyle.liquidGlass;

    if (!isGlass) {
      return SizedBox(
        width: width,
        height: 48,
        child: Theme(
          data: theme.copyWith(
            splashColor: colorScheme.primaryContainer.withValues(alpha: 0.3),
            highlightColor: Colors.transparent,
          ),
          child: TabBar(
            controller: controller,
            dividerColor: colorScheme.surfaceContainerHighest,
            indicatorColor: colorScheme.primary,
            indicatorSize: TabBarIndicatorSize.tab,
            indicatorWeight: 3.0,
            labelColor: colorScheme.primary,
            unselectedLabelColor: colorScheme.onSurfaceVariant,
            labelStyle: textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            unselectedLabelStyle: textTheme.titleSmall,
            tabs: tabs,
          ),
        ),
      );
    }

    final glassPrimary = resolveGlassStyle(
      colorScheme,
      brightness: brightness,
      role: GlassSurfaceRole.primary,
      isSelected: true,
    );
    final glassCard = resolveGlassStyle(
      colorScheme,
      brightness: brightness,
      role: GlassSurfaceRole.card,
    );

    return SharedSurface(
      uiStyle: uiStyle,
      borderRadius: borderRadius,
      glassRole: GlassSurfaceRole.card,
      frosted: true,
      padding: padding,
      child: SizedBox(
        width: width,
        height: height,
        child: TabBar(
          controller: controller,
          dividerColor: Colors.transparent,
          indicatorSize: TabBarIndicatorSize.tab,
          indicator: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius.topLeft.x * 0.85),
            border: Border.all(color: glassPrimary.borderColor, width: 1.0),
            boxShadow: glassPrimary.shadows,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(
                  glassPrimary.fillColor,
                  Colors.white,
                  brightness == Brightness.light ? 0.2 : 0.1,
                )!,
                glassPrimary.fillColor,
                Color.lerp(
                  glassPrimary.fillColor,
                  Colors.black,
                  brightness == Brightness.light ? 0.05 : 0.15,
                )!,
              ],
              stops: const [0.0, 0.4, 1.0],
            ),
          ),
          labelColor: glassPrimary.foregroundColor,
          unselectedLabelColor: glassCard.foregroundColor.withValues(
            alpha: 0.72,
          ),
          labelStyle: textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          unselectedLabelStyle: textTheme.titleSmall,
          splashBorderRadius: BorderRadius.circular(
            borderRadius.topLeft.x * 0.85,
          ),
          tabs: tabs,
        ),
      ),
    );
  }
}
