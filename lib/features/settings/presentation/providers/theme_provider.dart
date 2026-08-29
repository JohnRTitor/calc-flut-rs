import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:calc_flut_rs/app/theme/ui_style.dart';

part 'theme_provider.g.dart';

/// Defines the overall brightness and background style of the application.
enum AppThemeMode { light, dark, amoled, system }

/// Defines the primary color seed used for the Material 3 color scheme.
enum AppColorOption {
  defaultColor, // Green tinted
  materialYou, // Dynamic
  blue,
  purple,
  orange,
  red,
  pink,
  cyan,
  indigo,
}

/// A Riverpod Notifier that manages and persists the selected `AppThemeMode`.
@riverpod
class ThemeModeNotifier extends _$ThemeModeNotifier {
  @override
  AppThemeMode build() {
    _load();
    return AppThemeMode.system;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final idx = prefs.getInt('theme_mode') ?? 3;
    state = AppThemeMode.values[idx];
  }

  /// Updates the theme mode and persists it to SharedPreferences.
  Future<void> setThemeMode(AppThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme_mode', mode.index);
  }
}

/// A Riverpod Notifier that manages and persists the selected `AppColorOption`.
@riverpod
class AppColorNotifier extends _$AppColorNotifier {
  @override
  AppColorOption build() {
    _load();
    return AppColorOption.defaultColor;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final idx = prefs.getInt('app_color_option') ?? 0;
    if (idx >= 0 && idx < AppColorOption.values.length) {
      state = AppColorOption.values[idx];
    }
  }

  /// Updates the application color option and persists it to SharedPreferences.
  Future<void> setAppColorOption(AppColorOption option) async {
    state = option;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('app_color_option', option.index);
  }
}

/// A Riverpod Notifier that manages and persists the selected `UiStyle`.
@riverpod
class UiStyleNotifier extends _$UiStyleNotifier {
  @override
  UiStyle build() {
    _load();
    return UiStyle.material;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final idx = prefs.getInt('ui_style') ?? 0;
    if (idx >= 0 && idx < UiStyle.values.length) {
      state = UiStyle.values[idx];
    }
  }

  /// Updates the UI style and persists it to SharedPreferences.
  Future<void> setUiStyle(UiStyle style) async {
    state = style;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('ui_style', style.index);
  }
}
