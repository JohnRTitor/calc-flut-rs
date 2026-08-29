import 'package:flutter/material.dart';
import 'package:calc_flut_rs/app/theme/ui_style.dart';
import 'package:calc_flut_rs/shared/widgets/glass_utils.dart';
import 'package:calc_flut_rs/app/theme/app_theme_extension.dart';

/// A generic pill switcher that acts as a two-option segmented control.
///
/// If [UiStyle.liquidGlass] is active, it renders as a frosted glass pill containing
/// two selectable chips. If [UiStyle.material] is active, it falls back to the standard
/// Material 3 [SegmentedButton].
class PillSwitcher extends StatelessWidget {
  final UiStyle uiStyle;
  final String label1;
  final String label2;
  final bool isFirstSelected;
  final ValueChanged<bool> onChanged;

  final String? tooltip1;
  final String? tooltip2;

  const PillSwitcher({
    super.key,
    required this.uiStyle,
    required this.label1,
    required this.label2,
    this.tooltip1,
    this.tooltip2,
    required this.isFirstSelected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (uiStyle != UiStyle.liquidGlass) {
      return SegmentedButton<bool>(
        segments: [
          ButtonSegment<bool>(
            value: true,
            tooltip: tooltip1,
            label: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(label1),
            ),
          ),
          ButtonSegment<bool>(
            value: false,
            tooltip: tooltip2,
            label: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(label2),
            ),
          ),
        ],
        selected: {isFirstSelected},
        onSelectionChanged: (Set<bool> newSelection) {
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
        children: [
          Flexible(
            child: tooltip1 != null
                ? Tooltip(
                    message: tooltip1!,
                    child: _buildToggleChip(
                      context: context,
                      label: label1,
                      isSelected: isFirstSelected,
                      onTap: () {
                        if (!isFirstSelected) {
                          onChanged(true);
                        }
                      },
                    ),
                  )
                : _buildToggleChip(
                    context: context,
                    label: label1,
                    isSelected: isFirstSelected,
                    onTap: () {
                      if (!isFirstSelected) {
                        onChanged(true);
                      }
                    },
                  ),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: tooltip2 != null
                ? Tooltip(
                    message: tooltip2!,
                    child: _buildToggleChip(
                      context: context,
                      label: label2,
                      isSelected: !isFirstSelected,
                      onTap: () {
                        if (isFirstSelected) {
                          onChanged(false);
                        }
                      },
                    ),
                  )
                : _buildToggleChip(
                    context: context,
                    label: label2,
                    isSelected: !isFirstSelected,
                    onTap: () {
                      if (isFirstSelected) {
                        onChanged(false);
                      }
                    },
                  ),
          ),
        ],
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
              style: theme.textTheme.labelLarge!.copyWith(
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
