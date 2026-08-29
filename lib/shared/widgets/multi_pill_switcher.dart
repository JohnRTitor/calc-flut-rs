import 'package:flutter/material.dart';
import 'package:calc_flut_rs/app/theme/ui_style.dart';
import 'package:calc_flut_rs/shared/widgets/glass_utils.dart';
import 'package:calc_flut_rs/app/theme/app_theme_extension.dart';

class MultiPillSwitcher extends StatelessWidget {
  final UiStyle uiStyle;
  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  final List<String>? tooltips;

  const MultiPillSwitcher({
    super.key,
    required this.uiStyle,
    required this.labels,
    this.tooltips,
    required this.selectedIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (uiStyle != UiStyle.liquidGlass) {
      return SegmentedButton<int>(
        segments: labels.asMap().entries.map((entry) {
          return ButtonSegment<int>(
            value: entry.key,
            tooltip: tooltips?[entry.key],
            label: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Text(entry.value),
            ),
          );
        }).toList(),
        selected: {selectedIndex},
        onSelectionChanged: (Set<int> newSelection) {
          onChanged(newSelection.first);
        },
      );
    }

    // Liquid Glass Mode
    return SharedSurface(
      uiStyle: uiStyle,
      borderRadius: BorderRadius.circular(24),
      glassRole: GlassSurfaceRole.card,
      frosted: true,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: labels.asMap().entries.map((entry) {
          final isSelected = entry.key == selectedIndex;
          return Flexible(
            child: Padding(
              padding: EdgeInsets.only(
                right: entry.key < labels.length - 1 ? 4.0 : 0.0,
              ),
              child: tooltips != null
                  ? Tooltip(
                      message: tooltips![entry.key],
                      child: _buildToggleChip(
                        context: context,
                        label: entry.value,
                        isSelected: isSelected,
                        onTap: () {
                          if (!isSelected) {
                            onChanged(entry.key);
                          }
                        },
                      ),
                    )
                  : _buildToggleChip(
                      context: context,
                      label: entry.value,
                      isSelected: isSelected,
                      onTap: () {
                        if (!isSelected) {
                          onChanged(entry.key);
                        }
                      },
                    ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildToggleChip({
    required BuildContext context,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final themeExt = theme.extension<AppThemeExtension>()!;
    final bgColor = isSelected ? themeExt.chipBackground : Colors.transparent;
    final fgColor = isSelected
        ? themeExt.chipText
        : theme.colorScheme.onSurfaceVariant;

    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(20),
      animationDuration: const Duration(milliseconds: 200),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              style: theme.textTheme.labelMedium!.copyWith(
                color: fgColor,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
