import 'package:flutter/material.dart';

import 'package:calc_flut_rs/app/theme/ui_style.dart';
import 'package:calc_flut_rs/features/settings/presentation/providers/theme_provider.dart';
import 'package:calc_flut_rs/features/settings/presentation/widgets/settings_option_cards.dart';

/// The accent-colour picker, and the swatch it is built from.
///
/// The swatches show literal colours on purpose: a colour picker is the one
/// place where the point *is* the raw value, and resolving it through a
/// theme role would make the control lie about what it is offering.

class SettingsColorsSelector extends StatelessWidget {
  final UiStyle uiStyle;
  final ColorScheme colorScheme;
  final ThemeData theme;
  final AppColorOption selectedOption;
  final bool isDynamicColorSupported;
  final ValueChanged<AppColorOption> onColorOptionChanged;

  const SettingsColorsSelector({
    super.key,
    required this.uiStyle,
    required this.colorScheme,
    required this.theme,
    required this.selectedOption,
    required this.isDynamicColorSupported,
    required this.onColorOptionChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: SettingsOptionCard(
                label: 'Default',
                icon: Icons.format_color_fill,
                description: 'Green aesthetic',
                isSelected: selectedOption == AppColorOption.defaultColor,
                uiStyle: uiStyle,
                colorScheme: colorScheme,
                onTap: () => onColorOptionChanged(AppColorOption.defaultColor),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SettingsOptionCard(
                label: 'Material You',
                icon: Icons.auto_awesome,
                description: isDynamicColorSupported
                    ? 'Dynamic color'
                    : 'Not available',
                isSelected: selectedOption == AppColorOption.materialYou,
                uiStyle: uiStyle,
                colorScheme: colorScheme,
                isDisabled: !isDynamicColorSupported,
                onTap: isDynamicColorSupported
                    ? () => onColorOptionChanged(AppColorOption.materialYou)
                    : () {},
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Other Colors',
          style: theme.textTheme.labelMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              SettingsColorSwatch(
                color: Colors.blue,
                isSelected: selectedOption == AppColorOption.blue,
                onTap: () => onColorOptionChanged(AppColorOption.blue),
              ),
              const SizedBox(width: 12),
              SettingsColorSwatch(
                color: Colors.purple,
                isSelected: selectedOption == AppColorOption.purple,
                onTap: () => onColorOptionChanged(AppColorOption.purple),
              ),
              const SizedBox(width: 12),
              SettingsColorSwatch(
                color: Colors.orange,
                isSelected: selectedOption == AppColorOption.orange,
                onTap: () => onColorOptionChanged(AppColorOption.orange),
              ),
              const SizedBox(width: 12),
              SettingsColorSwatch(
                color: Colors.red,
                isSelected: selectedOption == AppColorOption.red,
                onTap: () => onColorOptionChanged(AppColorOption.red),
              ),
              const SizedBox(width: 12),
              SettingsColorSwatch(
                color: Colors.pink,
                isSelected: selectedOption == AppColorOption.pink,
                onTap: () => onColorOptionChanged(AppColorOption.pink),
              ),
              const SizedBox(width: 12),
              SettingsColorSwatch(
                color: Colors.cyan,
                isSelected: selectedOption == AppColorOption.cyan,
                onTap: () => onColorOptionChanged(AppColorOption.cyan),
              ),
              const SizedBox(width: 12),
              SettingsColorSwatch(
                color: Colors.indigo,
                isSelected: selectedOption == AppColorOption.indigo,
                onTap: () => onColorOptionChanged(AppColorOption.indigo),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Color Swatch ──
class SettingsColorSwatch extends StatelessWidget {
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const SettingsColorSwatch({
    super.key,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Colors.transparent,
            width: isSelected ? 3 : 0,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: color.withValues(alpha: 0.4),
                blurRadius: 8,
                spreadRadius: 2,
              ),
          ],
        ),
        child: isSelected
            ? Icon(
                Icons.check,
                color: color.computeLuminance() > 0.5
                    ? Colors.black
                    : Colors.white,
              )
            : null,
      ),
    );
  }
}

// ── Style Selector ──
