// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'history_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// A Riverpod Notifier that manages the history of calculations.
///
/// Interacts with the Rust backend to load, save, clear, and delete history entries.

@ProviderFor(History)
final historyProvider = HistoryProvider._();

/// A Riverpod Notifier that manages the history of calculations.
///
/// Interacts with the Rust backend to load, save, clear, and delete history entries.
final class HistoryProvider
    extends $AsyncNotifierProvider<History, List<HistoryEntry>> {
  /// A Riverpod Notifier that manages the history of calculations.
  ///
  /// Interacts with the Rust backend to load, save, clear, and delete history entries.
  HistoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'historyProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$historyHash();

  @$internal
  @override
  History create() => History();
}

String _$historyHash() => r'3bafd0c65ee60536bd1168a21a7c2eb97c28542c';

/// A Riverpod Notifier that manages the history of calculations.
///
/// Interacts with the Rust backend to load, save, clear, and delete history entries.

abstract class _$History extends $AsyncNotifier<List<HistoryEntry>> {
  FutureOr<List<HistoryEntry>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<List<HistoryEntry>>, List<HistoryEntry>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<HistoryEntry>>, List<HistoryEntry>>,
              AsyncValue<List<HistoryEntry>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
