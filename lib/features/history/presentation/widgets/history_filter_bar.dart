import 'package:flutter/material.dart';

import 'package:calc_flut_rs/app/theme/app_theme_extension.dart';
import 'package:calc_flut_rs/app/theme/ui_style.dart';
import 'package:calc_flut_rs/features/history/domain/history_category.dart';
import 'package:calc_flut_rs/shared/layouts/breakpoints.dart';
import 'package:calc_flut_rs/shared/widgets/app_chip.dart';
import 'package:calc_flut_rs/shared/widgets/glass_utils.dart';

/// Height of a filter chip row.
///
/// 48dp, Material's own minimum tap target, rather than
/// `AppChip.minimumTouchTarget` (40dp). That constant exists for the keypad's
/// tightly-packed scientific rows and the app bar's icon buttons, where 40 is
/// the space available; a filter row is a full-width control the user is meant
/// to hit accurately and repeatedly, and has no such constraint. Both numbers
/// are deliberate rather than one having drifted from the other.
const double _kFilterRowHeight = 48.0;

/// The history filter: a group row, plus a tool row for the groups that need one.
///
/// Replaces a single `MultiPillSwitcher` of every category at once. At four
/// categories that switcher ellipsised every label on a phone — "Calc...",
/// "Fn Ev...", "Symb..." — so the filter was illegible before a single entry
/// existed, and adding tools made it worse. Here the primary row is only ever
/// `All` plus the groups, and it scrolls rather than truncating, so the number
/// of registered tools cannot affect whether a label is readable.
class HistoryFilterBar extends StatelessWidget {
  final UiStyle uiStyle;

  /// The selected group, or `null` for the "All" view.
  final HistoryGroup? selectedGroup;

  /// The selected tool, or `null` when a whole group is selected.
  final HistoryCategory? selectedCategory;

  final ValueChanged<HistoryGroup?> onGroupChanged;
  final ValueChanged<HistoryCategory?> onToolChanged;

  const HistoryFilterBar({
    super.key,
    required this.uiStyle,
    required this.selectedGroup,
    required this.selectedCategory,
    required this.onGroupChanged,
    required this.onToolChanged,
  });

  @override
  Widget build(BuildContext context) {
    final groups = HistoryGroup.values;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ChipRow(
          // Stable keys, because a group's label and one of its tool's labels
          // can legitimately be the same string — the Calculator group's first
          // tool is also called "Calculator" — so the rows have to be
          // addressable independently of their contents.
          key: const ValueKey('history_group_row'),
          uiStyle: uiStyle,
          children: [
            _FilterChip(
              uiStyle: uiStyle,
              label: 'All',
              icon: Icons.inbox_outlined,
              tooltip: 'Every tool, most recent first',
              isSelected: selectedGroup == null && selectedCategory == null,
              onTap: () => onGroupChanged(null),
            ),
            for (final group in groups)
              _FilterChip(
                uiStyle: uiStyle,
                label: group.label,
                icon: group.icon,
                tooltip: group.tooltip,
                isSelected: selectedGroup == group && selectedCategory == null,
                onTap: () => onGroupChanged(group),
              ),
          ],
        ),
        // A single-tool group is not ambiguous, so it gets no second row.
        if (selectedCategory == null &&
            selectedGroup != null &&
            selectedGroup!.hasMultipleTools) ...[
          SizedBox(height: LayoutMetrics.compact.spacing * 0.5),
          _ChipRow(
            key: const ValueKey('history_tool_row'),
            uiStyle: uiStyle,
            children: [
              for (final tool in selectedGroup!.categories)
                _FilterChip(
                  uiStyle: uiStyle,
                  label: tool.label,
                  icon: tool.icon,
                  tooltip: tool.tooltip,
                  isSelected: false,
                  onTap: () => onToolChanged(tool),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// A horizontally scrolling row of filter chips.
///
/// Scrolling rather than squeezing is the point: a label that scrolls off the
/// edge is still legible, whereas one that shrinks to an ellipsis is not, and
/// the row has to stay usable no matter how many tools are registered.
class _ChipRow extends StatelessWidget {
  final UiStyle uiStyle;
  final List<Widget> children;

  const _ChipRow({super.key, required this.uiStyle, required this.children});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _kFilterRowHeight,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        physics: const BouncingScrollPhysics(),
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// One selectable filter chip.
///
/// Built on the shared [AppChip] so it matches every other pill in the app, and
/// carries a minimum touch target to match the icon-button convention.
class _FilterChip extends StatelessWidget {
  final UiStyle uiStyle;
  final String label;
  final IconData icon;
  final String tooltip;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.uiStyle,
    required this.label,
    required this.icon,
    required this.tooltip,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeExt = theme.extension<AppThemeExtension>()!;
    final colorScheme = theme.colorScheme;

    return AppChip(
      uiStyle: uiStyle,
      label: label,
      backgroundColor: isSelected
          ? themeExt.chipBackground
          : colorScheme.surfaceContainerHigh,
      foregroundColor: isSelected
          ? themeExt.chipText
          : onGlassSecondary(context, uiStyle),
      onTap: onTap,
      minimumHeight: _kFilterRowHeight,
      leading: Icon(icon, size: 16),
      semanticLabel: tooltip,
    );
  }
}
