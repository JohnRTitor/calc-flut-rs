import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:calc_flut_rs/app/theme/ui_style.dart';
import 'package:calc_flut_rs/features/settings/presentation/providers/theme_provider.dart';
import 'package:calc_flut_rs/features/settings/presentation/providers/settings_provider.dart';
import 'package:calc_flut_rs/features/settings/presentation/widgets/settings_color_selector.dart';
import 'package:calc_flut_rs/features/settings/presentation/widgets/settings_option_cards.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// The settings screen where users can configure the application's appearance.
///
/// Provides options for selecting the theme mode (Light, Dark, System, AMOLED),
/// app accent colors (including Material You dynamic color support if available),
/// and the overall visual style (Standard Material vs. Liquid Glass).
class SettingsScreen extends ConsumerWidget {
  /// When true the screen is hosted as a top level section inside `AppShell`,
  /// which already renders the title in its app bar. Suppresses this screen's
  /// own app bar so the title is not shown twice.
  final bool embedded;

  const SettingsScreen({super.key, this.embedded = false});

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
                    SettingsSectionHeader(
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
                    SettingsSectionHeader(
                      label: 'Colors',
                      colorScheme: colorScheme,
                      textTheme: theme.textTheme,
                    ),
                    const SizedBox(height: 8),
                    SettingsColorsSelector(
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
                    SettingsSectionHeader(
                      label: 'Visual Style',
                      colorScheme: colorScheme,
                      textTheme: theme.textTheme,
                    ),
                    const SizedBox(height: 8),
                    SettingsStyleSelector(
                      uiStyle: uiStyle,
                      colorScheme: colorScheme,
                      theme: theme,
                      onStyleChanged: (style) =>
                          ref.read(uiStyleProvider.notifier).setUiStyle(style),
                    ),
                    const SizedBox(height: 28),

                    // ── Educational Settings Section ──
                    SettingsSectionHeader(
                      label: 'Educational Settings',
                      colorScheme: colorScheme,
                      textTheme: theme.textTheme,
                    ),
                    const SizedBox(height: 8),
                    SettingsSwitchCard(
                      label: 'Educational Mode',
                      description:
                          'Show step-by-step working where a tool can provide it',
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
          appBar: embedded ? null : AppBar(title: const Text('Settings')),
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

    return SettingsOptionCard(
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
