import 'package:flutter/material.dart';

import 'package:calc_flut_rs/app/theme/ui_style.dart';
import 'package:calc_flut_rs/shared/layouts/breakpoints.dart';
import 'package:calc_flut_rs/shared/widgets/glass_utils.dart';

/// The presentational leaves of the ring analysis view.
///
/// Split from the grid that arranges them, because the grid is a function of the
/// analysis and these are not: they are a tile, a notice and a chip row, each
/// independent of which sections exist and in what order.
class ModularAnalysisMetricTile extends StatelessWidget {
  final UiStyle uiStyle;
  final String title;
  final String value;
  final VoidCallback? onTap;
  final bool isExpanded;

  const ModularAnalysisMetricTile({
    super.key,
    required this.uiStyle,
    required this.title,
    required this.value,
    this.onTap,
    this.isExpanded = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isInteractive = onTap != null;

    return Semantics(
      button: isInteractive,
      expanded: isInteractive ? isExpanded : null,
      label: isInteractive
          ? '$title $value. Show the ${title.replaceAll(':', '').trim()} list.'
          : '$title $value',
      child: SharedSurface(
        uiStyle: uiStyle,
        glassRole: GlassSurfaceRole.card,
        frosted: true,
        borderRadius: BorderRadius.circular(LayoutMetrics.compact.borderRadius),
        isSelected: isExpanded,
        onTap: onTap,
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: onGlassSecondary(context, uiStyle),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // An open section says so, so the tile still reads as a
                // control after the section below it has appeared.
                if (isInteractive)
                  Icon(
                    isExpanded
                        ? Icons.expand_less
                        : Icons.arrow_forward_ios_rounded,
                    size: 12,
                    color: onGlassSecondary(context, uiStyle),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: isInteractive
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The banner shown when element lists were capped.
class ModularAnalysisTruncationNotice extends StatelessWidget {
  final UiStyle uiStyle;
  final VoidCallback onExplain;

  const ModularAnalysisTruncationNotice({
    super.key,
    required this.uiStyle,
    required this.onExplain,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SharedSurface(
      uiStyle: uiStyle,
      glassRole: GlassSurfaceRole.accent,
      frosted: true,
      padding: const EdgeInsets.all(12),
      borderRadius: BorderRadius.circular(12),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: theme.colorScheme.error),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Large dataset: Item lists are capped at 10,000.',
              style: theme.textTheme.bodyMedium,
            ),
          ),
          TextButton(onPressed: onExplain, child: const Text('Learn More')),
        ],
      ),
    );
  }
}

/// The element names of a set, as chips.
class ModularAnalysisDataChips extends StatelessWidget {
  final List<String> items;

  const ModularAnalysisDataChips({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final item in items)
            Chip(
              label: Text(item),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
        ],
      ),
    );
  }
}
