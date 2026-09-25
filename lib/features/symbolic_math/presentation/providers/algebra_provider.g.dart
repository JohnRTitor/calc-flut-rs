// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'algebra_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Drives the Algebra workspace.
///
/// Every symbolic call goes through the async bridge, so no method here blocks
/// the UI thread: the numeric calculator's synchronous fast path is untouched
/// and unaffected by this feature.

@ProviderFor(Algebra)
final algebraProvider = AlgebraProvider._();

/// Drives the Algebra workspace.
///
/// Every symbolic call goes through the async bridge, so no method here blocks
/// the UI thread: the numeric calculator's synchronous fast path is untouched
/// and unaffected by this feature.
final class AlgebraProvider extends $NotifierProvider<Algebra, AlgebraState> {
  /// Drives the Algebra workspace.
  ///
  /// Every symbolic call goes through the async bridge, so no method here blocks
  /// the UI thread: the numeric calculator's synchronous fast path is untouched
  /// and unaffected by this feature.
  AlgebraProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'algebraProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$algebraHash();

  @$internal
  @override
  Algebra create() => Algebra();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AlgebraState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AlgebraState>(value),
    );
  }
}

String _$algebraHash() => r'c6fff4c596971be7b6371eeb79f4b78e964d0bcd';

/// Drives the Algebra workspace.
///
/// Every symbolic call goes through the async bridge, so no method here blocks
/// the UI thread: the numeric calculator's synchronous fast path is untouched
/// and unaffected by this feature.

abstract class _$Algebra extends $Notifier<AlgebraState> {
  AlgebraState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AlgebraState, AlgebraState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AlgebraState, AlgebraState>,
              AlgebraState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
