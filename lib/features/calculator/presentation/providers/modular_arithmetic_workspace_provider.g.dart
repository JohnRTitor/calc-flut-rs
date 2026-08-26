// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'modular_arithmetic_workspace_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ModularArithmeticWorkspace)
final modularArithmeticWorkspaceProvider =
    ModularArithmeticWorkspaceProvider._();

final class ModularArithmeticWorkspaceProvider
    extends
        $NotifierProvider<
          ModularArithmeticWorkspace,
          ModularArithmeticWorkspaceState
        > {
  ModularArithmeticWorkspaceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'modularArithmeticWorkspaceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$modularArithmeticWorkspaceHash();

  @$internal
  @override
  ModularArithmeticWorkspace create() => ModularArithmeticWorkspace();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ModularArithmeticWorkspaceState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ModularArithmeticWorkspaceState>(
        value,
      ),
    );
  }
}

String _$modularArithmeticWorkspaceHash() =>
    r'3c9d8467253898447896633eff3c2b10b7e99d05';

abstract class _$ModularArithmeticWorkspace
    extends $Notifier<ModularArithmeticWorkspaceState> {
  ModularArithmeticWorkspaceState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              ModularArithmeticWorkspaceState,
              ModularArithmeticWorkspaceState
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                ModularArithmeticWorkspaceState,
                ModularArithmeticWorkspaceState
              >,
              ModularArithmeticWorkspaceState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
