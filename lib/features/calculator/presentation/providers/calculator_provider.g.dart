// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'calculator_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// A Riverpod Notifier that manages the state of the calculator.
///
/// Handles expression editing, mode switching, interacting with the Rust backend
/// for evaluation, and memory operations.

@ProviderFor(Calculator)
final calculatorProvider = CalculatorProvider._();

/// A Riverpod Notifier that manages the state of the calculator.
///
/// Handles expression editing, mode switching, interacting with the Rust backend
/// for evaluation, and memory operations.
final class CalculatorProvider
    extends $NotifierProvider<Calculator, CalculatorState> {
  /// A Riverpod Notifier that manages the state of the calculator.
  ///
  /// Handles expression editing, mode switching, interacting with the Rust backend
  /// for evaluation, and memory operations.
  CalculatorProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'calculatorProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$calculatorHash();

  @$internal
  @override
  Calculator create() => Calculator();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CalculatorState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CalculatorState>(value),
    );
  }
}

String _$calculatorHash() => r'158c52e3c6eed4331bfc69e03f36059d4e339cf2';

/// A Riverpod Notifier that manages the state of the calculator.
///
/// Handles expression editing, mode switching, interacting with the Rust backend
/// for evaluation, and memory operations.

abstract class _$Calculator extends $Notifier<CalculatorState> {
  CalculatorState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<CalculatorState, CalculatorState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<CalculatorState, CalculatorState>,
              CalculatorState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
