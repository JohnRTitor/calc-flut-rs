// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'theme_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// A Riverpod Notifier that manages and persists the selected `AppThemeMode`.

@ProviderFor(ThemeModeNotifier)
final themeModeProvider = ThemeModeNotifierProvider._();

/// A Riverpod Notifier that manages and persists the selected `AppThemeMode`.
final class ThemeModeNotifierProvider
    extends $NotifierProvider<ThemeModeNotifier, AppThemeMode> {
  /// A Riverpod Notifier that manages and persists the selected `AppThemeMode`.
  ThemeModeNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'themeModeProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$themeModeNotifierHash();

  @$internal
  @override
  ThemeModeNotifier create() => ThemeModeNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppThemeMode value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppThemeMode>(value),
    );
  }
}

String _$themeModeNotifierHash() => r'938d904dceccbb32d5c157f7957b6b37378ab732';

/// A Riverpod Notifier that manages and persists the selected `AppThemeMode`.

abstract class _$ThemeModeNotifier extends $Notifier<AppThemeMode> {
  AppThemeMode build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AppThemeMode, AppThemeMode>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AppThemeMode, AppThemeMode>,
              AppThemeMode,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// A Riverpod Notifier that manages and persists the selected `AppColorOption`.

@ProviderFor(AppColorNotifier)
final appColorProvider = AppColorNotifierProvider._();

/// A Riverpod Notifier that manages and persists the selected `AppColorOption`.
final class AppColorNotifierProvider
    extends $NotifierProvider<AppColorNotifier, AppColorOption> {
  /// A Riverpod Notifier that manages and persists the selected `AppColorOption`.
  AppColorNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appColorProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appColorNotifierHash();

  @$internal
  @override
  AppColorNotifier create() => AppColorNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppColorOption value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppColorOption>(value),
    );
  }
}

String _$appColorNotifierHash() => r'ee6b5d65ce26cdf843c201e9c946d647c6f2606d';

/// A Riverpod Notifier that manages and persists the selected `AppColorOption`.

abstract class _$AppColorNotifier extends $Notifier<AppColorOption> {
  AppColorOption build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AppColorOption, AppColorOption>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AppColorOption, AppColorOption>,
              AppColorOption,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// A Riverpod Notifier that manages and persists the selected `UiStyle`.

@ProviderFor(UiStyleNotifier)
final uiStyleProvider = UiStyleNotifierProvider._();

/// A Riverpod Notifier that manages and persists the selected `UiStyle`.
final class UiStyleNotifierProvider
    extends $NotifierProvider<UiStyleNotifier, UiStyle> {
  /// A Riverpod Notifier that manages and persists the selected `UiStyle`.
  UiStyleNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'uiStyleProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$uiStyleNotifierHash();

  @$internal
  @override
  UiStyleNotifier create() => UiStyleNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(UiStyle value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<UiStyle>(value),
    );
  }
}

String _$uiStyleNotifierHash() => r'd2641d05ef44d02d63a4857e6ece7bdf18331138';

/// A Riverpod Notifier that manages and persists the selected `UiStyle`.

abstract class _$UiStyleNotifier extends $Notifier<UiStyle> {
  UiStyle build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<UiStyle, UiStyle>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<UiStyle, UiStyle>,
              UiStyle,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
