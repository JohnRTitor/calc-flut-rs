// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'section_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Remembers which top level section of the app shell was last visible.
///
/// Persisted to SharedPreferences so relaunching the app returns the user to
/// where they left off. Unknown or stale ids fall back to [kDefaultSectionId].

@ProviderFor(SelectedSectionNotifier)
final selectedSectionProvider = SelectedSectionNotifierProvider._();

/// Remembers which top level section of the app shell was last visible.
///
/// Persisted to SharedPreferences so relaunching the app returns the user to
/// where they left off. Unknown or stale ids fall back to [kDefaultSectionId].
final class SelectedSectionNotifierProvider
    extends $NotifierProvider<SelectedSectionNotifier, String> {
  /// Remembers which top level section of the app shell was last visible.
  ///
  /// Persisted to SharedPreferences so relaunching the app returns the user to
  /// where they left off. Unknown or stale ids fall back to [kDefaultSectionId].
  SelectedSectionNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'selectedSectionProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$selectedSectionNotifierHash();

  @$internal
  @override
  SelectedSectionNotifier create() => SelectedSectionNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String>(value),
    );
  }
}

String _$selectedSectionNotifierHash() =>
    r'22fdefdf28d53164a10d615d40c9a35be3e8ed96';

/// Remembers which top level section of the app shell was last visible.
///
/// Persisted to SharedPreferences so relaunching the app returns the user to
/// where they left off. Unknown or stale ids fall back to [kDefaultSectionId].

abstract class _$SelectedSectionNotifier extends $Notifier<String> {
  String build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<String, String>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<String, String>,
              String,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
