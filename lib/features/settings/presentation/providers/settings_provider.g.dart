// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'settings_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// A Riverpod Notifier that manages and persists the Educational Mode setting.

@ProviderFor(EducationalModeNotifier)
final educationalModeProvider = EducationalModeNotifierProvider._();

/// A Riverpod Notifier that manages and persists the Educational Mode setting.
final class EducationalModeNotifierProvider
    extends $NotifierProvider<EducationalModeNotifier, bool> {
  /// A Riverpod Notifier that manages and persists the Educational Mode setting.
  EducationalModeNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'educationalModeProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$educationalModeNotifierHash();

  @$internal
  @override
  EducationalModeNotifier create() => EducationalModeNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$educationalModeNotifierHash() =>
    r'10eda0109b1934a03c207a28207e72bea46f2afa';

/// A Riverpod Notifier that manages and persists the Educational Mode setting.

abstract class _$EducationalModeNotifier extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<bool, bool>,
              bool,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
