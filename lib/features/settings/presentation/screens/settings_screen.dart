import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:calculator_flutter_app/app/theme/ui_style.dart';
import 'package:calculator_flutter_app/shared/widgets/glass_utils.dart';
import 'package:calculator_flutter_app/features/settings/presentation/providers/theme_provider.dart';
import 'package:calculator_flutter_app/features/settings/presentation/providers/settings_provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// The settings screen where users can configure the application's appearance.
///
/// Provides options for selecting the theme mode (Light, Dark, System, AMOLED),
/// app accent colors (including Material You dynamic color support if available),
/// and the overall visual style (Standard Material vs. Liquid Glass).
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const _themeLabels = {
    AppThemeMode.system: ('System', Icons.brightness_auto),
    AppThemeMode.light: ('Light', Icons.light_mode),
    AppThemeMode.dark: ('Dark', Icons.dark_mode),
    AppThemeMode.amoled: ('AMOLED', Icons.contrast),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final uiStyle = ref.watch(uiStyleProvider);
    final colorOption = ref.watch(appColorProvider);
    final isEducationalMode = ref.watch(educationalModeProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        final isDynamicColorSupported = lightDynamic != null;

        Widget body = ListView(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 8,
            bottom: 8 + MediaQuery.paddingOf(context).bottom,
          ),
          children:
              [
                    // ── Theme Section ──
                    _SectionHeader(
                      label: 'Theme',
                      colorScheme: colorScheme,
                      textTheme: theme.textTheme,
                    ),
                    const SizedBox(height: 8),
                    Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _buildThemeCard(
                                AppThemeMode.system,
                                themeMode,
                                uiStyle,
                                colorScheme,
                                ref,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildThemeCard(
                                AppThemeMode.light,
                                themeMode,
                                uiStyle,
                                colorScheme,
                                ref,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildThemeCard(
                                AppThemeMode.dark,
                                themeMode,
                                uiStyle,
                                colorScheme,
                                ref,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildThemeCard(
                                AppThemeMode.amoled,
                                themeMode,
                                uiStyle,
                                colorScheme,
                                ref,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 28),

                    // ── Colors Section ──
                    _SectionHeader(
                      label: 'Colors',
                      colorScheme: colorScheme,
                      textTheme: theme.textTheme,
                    ),
                    const SizedBox(height: 8),
                    _ColorsSelector(
                      uiStyle: uiStyle,
                      colorScheme: colorScheme,
                      theme: theme,
                      selectedOption: colorOption,
                      isDynamicColorSupported: isDynamicColorSupported,
                      onColorOptionChanged: (option) => ref
                          .read(appColorProvider.notifier)
                          .setAppColorOption(option),
                    ),

                    const SizedBox(height: 28),

                    // ── Style Section ──
                    _SectionHeader(
                      label: 'Visual Style',
                      colorScheme: colorScheme,
                      textTheme: theme.textTheme,
                    ),
                    const SizedBox(height: 8),
                    _StyleSelector(
                      uiStyle: uiStyle,
                      colorScheme: colorScheme,
                      theme: theme,
                      onStyleChanged: (style) =>
                          ref.read(uiStyleProvider.notifier).setUiStyle(style),
                    ),
                    const SizedBox(height: 28),

                    // ── Educational Settings Section ──
                    _SectionHeader(
                      label: 'Educational Settings',
                      colorScheme: colorScheme,
                      textTheme: theme.textTheme,
                    ),
                    const SizedBox(height: 8),
                    _SettingsSwitchCard(
                      label: 'Educational Mode',
                      description:
                          'Show step-by-step explanations in Modular workspace',
                      icon: Icons.school_outlined,
                      value: isEducationalMode,
                      uiStyle: uiStyle,
                      colorScheme: colorScheme,
                      onChanged: (val) => ref
                          .read(educationalModeProvider.notifier)
                          .setEducationalMode(val),
                    ),
                  ]
                  .animate(interval: 50.ms)
                  .fade(duration: 400.ms)
                  .slideY(
                    begin: 0.1,
                    end: 0,
                    duration: 400.ms,
                    curve: Curves.easeOutQuart,
                  ),
        );

        return Scaffold(
          appBar: AppBar(title: const Text('Settings')),
          body: body,
        );
      },
    );
  }

  Widget _buildThemeCard(
    AppThemeMode mode,
    AppThemeMode currentMode,
    UiStyle uiStyle,
    ColorScheme colorScheme,
    WidgetRef ref,
  ) {
    final (label, icon) = _themeLabels[mode]!;
    final isSelected = currentMode == mode;

    String description;
    switch (mode) {
      case AppThemeMode.system:
        description = 'Follow system';
        break;
      case AppThemeMode.light:
        description = 'Light colors';
        break;
      case AppThemeMode.dark:
        description = 'Dark colors';
        break;
      case AppThemeMode.amoled:
        description = 'Pitch black';
        break;
    }

    return _SettingsOptionCard(
      label: label,
      icon: icon,
      description: description,
      isSelected: isSelected,
      uiStyle: uiStyle,
      colorScheme: colorScheme,
      onTap: () => ref.read(themeModeProvider.notifier).setThemeMode(mode),
    );
  }
}

// ── Section Header ──
class _SectionHeader extends StatelessWidget {
  final String label;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  const _SectionHeader({
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
class _ColorsSelector extends StatelessWidget {
  final UiStyle uiStyle;
  final ColorScheme colorScheme;
  final ThemeData theme;
  final AppColorOption selectedOption;
  final bool isDynamicColorSupported;
  final ValueChanged<AppColorOption> onColorOptionChanged;

  const _ColorsSelector({
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
              child: _SettingsOptionCard(
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
              child: _SettingsOptionCard(
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
              _ColorSwatch(
                color: Colors.blue,
                isSelected: selectedOption == AppColorOption.blue,
                onTap: () => onColorOptionChanged(AppColorOption.blue),
              ),
              const SizedBox(width: 12),
              _ColorSwatch(
                color: Colors.purple,
                isSelected: selectedOption == AppColorOption.purple,
                onTap: () => onColorOptionChanged(AppColorOption.purple),
              ),
              const SizedBox(width: 12),
              _ColorSwatch(
                color: Colors.orange,
                isSelected: selectedOption == AppColorOption.orange,
                onTap: () => onColorOptionChanged(AppColorOption.orange),
              ),
              const SizedBox(width: 12),
              _ColorSwatch(
                color: Colors.red,
                isSelected: selectedOption == AppColorOption.red,
                onTap: () => onColorOptionChanged(AppColorOption.red),
              ),
              const SizedBox(width: 12),
              _ColorSwatch(
                color: Colors.pink,
                isSelected: selectedOption == AppColorOption.pink,
                onTap: () => onColorOptionChanged(AppColorOption.pink),
              ),
              const SizedBox(width: 12),
              _ColorSwatch(
                color: Colors.cyan,
                isSelected: selectedOption == AppColorOption.cyan,
                onTap: () => onColorOptionChanged(AppColorOption.cyan),
              ),
              const SizedBox(width: 12),
              _ColorSwatch(
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
class _ColorSwatch extends StatelessWidget {
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _ColorSwatch({
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
class _StyleSelector extends StatelessWidget {
  final UiStyle uiStyle;
  final ColorScheme colorScheme;
  final ThemeData theme;
  final ValueChanged<UiStyle> onStyleChanged;

  const _StyleSelector({
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
          child: _SettingsOptionCard(
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
          child: _SettingsOptionCard(
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
class _SettingsOptionCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final String? description;
  final bool isSelected;
  final UiStyle uiStyle;
  final ColorScheme colorScheme;
  final bool isDisabled;
  final VoidCallback onTap;

  const _SettingsOptionCard({
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
class _SettingsSwitchCard extends StatelessWidget {
  final String label;
  final String description;
  final IconData icon;
  final bool value;
  final UiStyle uiStyle;
  final ColorScheme colorScheme;
  final ValueChanged<bool> onChanged;

  const _SettingsSwitchCard({
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
    if (uiStyle == UiStyle.liquidGlass) {
      return SharedSurface(
        uiStyle: uiStyle,
        isInteractive: false,
        glassRole: GlassSurfaceRole.card,
        borderRadius: BorderRadius.circular(16),
        child: _buildContent(),
      );
    } else {
      return Container(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
        ),
        child: _buildContent(),
      );
    }
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
