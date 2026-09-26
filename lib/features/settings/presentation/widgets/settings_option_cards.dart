import 'package:flutter/material.dart';

import 'package:calc_flut_rs/app/theme/ui_style.dart';
import 'package:calc_flut_rs/shared/widgets/glass_utils.dart';

/// The section headings and option rows the settings screen is built from.

class SettingsSectionHeader extends StatelessWidget {
  final String label;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  const SettingsSectionHeader({
    super.key,
    required this.label,
    required this.colorScheme,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        label,
        style: textTheme.labelLarge?.copyWith(
          color: colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ── Colors Selector ──
class SettingsStyleSelector extends StatelessWidget {
  final UiStyle uiStyle;
  final ColorScheme colorScheme;
  final ThemeData theme;
  final ValueChanged<UiStyle> onStyleChanged;

  const SettingsStyleSelector({
    super.key,
    required this.uiStyle,
    required this.colorScheme,
    required this.theme,
    required this.onStyleChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SettingsOptionCard(
            label: 'Material',
            icon: Icons.layers_outlined,
            description: 'Standard design',
            isSelected: uiStyle == UiStyle.material,
            uiStyle: uiStyle,
            colorScheme: colorScheme,
            onTap: () => onStyleChanged(UiStyle.material),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SettingsOptionCard(
            label: 'Liquid Glass',
            icon: Icons.blur_on,
            description: 'Translucent glass',
            isSelected: uiStyle == UiStyle.liquidGlass,
            uiStyle: uiStyle,
            colorScheme: colorScheme,
            onTap: () => onStyleChanged(UiStyle.liquidGlass),
          ),
        ),
      ],
    );
  }
}

// ── Settings Option Card ──
class SettingsOptionCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final String? description;
  final bool isSelected;
  final UiStyle uiStyle;
  final ColorScheme colorScheme;
  final bool isDisabled;
  final VoidCallback onTap;

  const SettingsOptionCard({
    super.key,
    required this.label,
    required this.icon,
    this.description,
    required this.isSelected,
    required this.uiStyle,
    required this.colorScheme,
    this.isDisabled = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Widget card;
    if (uiStyle == UiStyle.liquidGlass) {
      card = _buildGlassVariant(context);
    } else {
      card = _buildMaterialVariant();
    }

    if (isDisabled) {
      return Opacity(opacity: 0.5, child: card);
    }
    return card;
  }

  Widget _buildMaterialVariant() {
    return AnimatedScale(
      scale: isSelected ? 1.02 : 0.95,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primaryContainer
              : colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? colorScheme.primary : Colors.transparent,
            width: 2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: colorScheme.primary.withValues(alpha: 0.2),
                    blurRadius: 12,
                    spreadRadius: 0,
                  ),
                ]
              : [],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: _buildContent(),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassVariant(BuildContext context) {
    return AnimatedScale(
      scale: isSelected ? 1.02 : 0.95,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      child: SharedSurface(
        uiStyle: uiStyle,
        isInteractive: true,
        isSelected: isSelected,
        glassRole: isSelected
            ? GlassSurfaceRole.primary
            : GlassSurfaceRole.card,
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          child: _buildContent(context),
        ),
      ),
    );
  }

  Widget _buildContent([BuildContext? context]) {
    final selectedColor = colorScheme.onPrimaryContainer;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 28,
            color: isSelected ? selectedColor : colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected ? selectedColor : colorScheme.onSurfaceVariant,
            ),
          ),
          if (description != null) ...[
            const SizedBox(height: 2),
            Text(
              description!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color:
                    (isSelected ? selectedColor : colorScheme.onSurfaceVariant)
                        .withValues(alpha: 0.7),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Settings Switch Card ──
class SettingsSwitchCard extends StatelessWidget {
  final String label;
  final String description;
  final IconData icon;
  final bool value;
  final UiStyle uiStyle;
  final ColorScheme colorScheme;
  final ValueChanged<bool> onChanged;

  const SettingsSwitchCard({
    super.key,
    required this.label,
    required this.description,
    required this.icon,
    required this.value,
    required this.uiStyle,
    required this.colorScheme,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    // SharedSurface renders a Material in material mode, so the ListTile inside
    // the switch paints its selected state and ink on this surface. A raw
    // Container with a background would sit between the two and hide them.
    return SharedSurface(
      uiStyle: uiStyle,
      glassRole: GlassSurfaceRole.card,
      borderRadius: BorderRadius.circular(16),
      materialColor: colorScheme.surfaceContainerHigh,
      child: _buildContent(),
    );
  }

  Widget _buildContent() {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      title: Text(
        label,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: colorScheme.onSurface,
        ),
      ),
      subtitle: Text(
        description,
        style: TextStyle(
          fontSize: 13,
          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
        ),
      ),
      secondary: Icon(icon, color: colorScheme.primary, size: 28),
      activeThumbColor: colorScheme.onPrimary,
      activeTrackColor: colorScheme.primary,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }
}
