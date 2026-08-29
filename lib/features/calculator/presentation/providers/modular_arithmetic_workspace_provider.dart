import 'dart:convert';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:calc_flut_rs/features/calculator/presentation/providers/modular_arithmetic_workspace_state.dart';
import 'package:calc_flut_rs/generated/rust/bridge/modular_arithmetic.dart'
    as rust;
import 'package:calc_flut_rs/generated/rust/bridge/history.dart'
    as rust_history;
import 'package:calc_flut_rs/features/history/presentation/providers/history_provider.dart';
import 'package:calc_flut_rs/features/settings/presentation/providers/settings_provider.dart';

part 'modular_arithmetic_workspace_provider.g.dart';

@riverpod
class ModularArithmeticWorkspace extends _$ModularArithmeticWorkspace {
  @override
  ModularArithmeticWorkspaceState build() {
    return const ModularArithmeticWorkspaceState();
  }

  void updateExpression(String expr) {
    state = state.copyWith(expression: expr, clearError: true);
    _updatePreview();
  }

  void updateModulus(String modulus) {
    state = state.copyWith(modulus: modulus, clearError: true);
    _updatePreview();
  }

  void setMode(ModularMode mode) {
    state = state.copyWith(mode: mode, clearError: true);
    _updatePreview();
  }

  void append(String text) {
    if (state.showResult) {
      state = state.copyWith(
        expression: text,
        showResult: false,
        clearError: true,
      );
    } else {
      state = state.copyWith(
        expression: state.expression + text,
        clearError: true,
      );
    }
    _updatePreview();
  }

  void delete() {
    if (state.showResult) {
      state = state.copyWith(
        expression: '',
        showResult: false,
        preview: '',
        clearError: true,
      );
    } else if (state.expression.isNotEmpty) {
      state = state.copyWith(
        expression: state.expression.substring(0, state.expression.length - 1),
        clearError: true,
      );
      _updatePreview();
    }
  }

  void clear() {
    state = const ModularArithmeticWorkspaceState();
  }

  void _updatePreview() {
    if (state.expression.trim().isEmpty) {
      state = state.copyWith(preview: '');
      return;
    }

    try {
      final res = rust.modularEvaluate(
        expression: state.expression,
        contextModulus: state.modulus.isEmpty ? null : state.modulus,
        mode: state.mode.name,
        showSteps: false, // Don't compute steps for preview
      );
      state = state.copyWith(preview: res.value);
    } catch (e) {
      state = state.copyWith(preview: '');
    }
  }

  void evaluate() {
    if (state.expression.trim().isEmpty) return;

    try {
      final showSteps = ref.read(educationalModeProvider);

      final res = rust.modularEvaluate(
        expression: state.expression,
        contextModulus: state.modulus.isEmpty ? null : state.modulus,
        mode: state.mode.name,
        showSteps: showSteps,
      );

      rust_history.appHistoryAdd(
        category: 'modularArithmetic',
        preview: jsonEncode({
          'operation': state.mode.name,
          'modulus': state.modulus,
          'inputs': state.expression,
          'result': res.value,
        }),
        snapshot: jsonEncode({
          'expression': state.expression,
          'modulus': state.modulus,
          'mode': state.mode.name,
          'result': res.value,
          'details': res.details,
          'modulusUsed': res.modulusUsed,
          'steps': res.steps,
        }),
      );

      final historyNotifier = ref.read(historyProvider.notifier);
      historyNotifier.saveHistoryToFile();
      historyNotifier.refresh();

      state = state.copyWith(
        result: res.value,
        details: res.details,
        modulusUsed: res.modulusUsed,
        steps: res.steps,
        showResult: true,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(
        error: e
            .toString()
            .replaceAll('AnyhowException(', '')
            .replaceAll(')', ''),
      );
    }
  }

  void setExplorerN(String n) {
    state = state.copyWith(
      explorerN: n,
      clearExplorerError: true,
      clearExplorerSuggestion: true,
      clearExplorerInterpretedAs: true,
    );
  }

  void setExplorerType(String type) {
    state = state.copyWith(
      explorerType: type,
      clearExplorerError: true,
      clearExplorerSuggestion: true,
      clearExplorerInterpretedAs: true,
    );
  }

  void analyzeStructure() {
    if (state.explorerN.trim().isEmpty) return;

    try {
      final res = rust.analyzeStructure(
        structureType: state.explorerType,
        n: state.explorerN,
      );

      if (res.success && res.analysis != null) {
        // Also add to rich history
        rust_history.appHistoryAdd(
          category: 'modularArithmetic',
          preview: jsonEncode({
            'operation': 'analyze',
            'modulus': state.explorerN,
            'inputs': state.explorerType,
            'result': res.analysis!.classification,
          }),
          snapshot: jsonEncode({
            'explorerN': state.explorerN,
            'explorerType': state.explorerType,
          }), // Since structure explorer is just a tab, maybe we don't restore fully into it, or we could if we extend state
        );

        final historyNotifier = ref.read(historyProvider.notifier);
        historyNotifier.saveHistoryToFile();
        historyNotifier.refresh();

        state = state.copyWith(
          explorerResult: res.analysis,
          explorerInterpretedAs: res.interpretedAs,
          clearExplorerError: true,
          clearExplorerSuggestion: true,
        );
      } else {
        // Handle parser suggestions or mathematical errors
        state = state.copyWith(
          explorerError: res.errorMessage,
          clearExplorerError: res.errorMessage == null,
          explorerSuggestion: res.suggestion,
          clearExplorerSuggestion: res.suggestion == null,
          clearExplorerResult: true,
          clearExplorerInterpretedAs: true,
        );
      }
    } catch (e) {
      state = state.copyWith(
        explorerError: e
            .toString()
            .replaceAll('AnyhowException(', '')
            .replaceAll(')', ''),
        clearExplorerSuggestion: true,
        clearExplorerInterpretedAs: true,
      );
    }
  }

  /// Restores the evaluator state from a history snapshot.
  void restoreSnapshot(String snapshotJson) {
    try {
      final Map<String, dynamic> data = jsonDecode(snapshotJson);
      
      final modeStr = data['mode'] as String? ?? 'ring';
      final mode = ModularMode.values.firstWhere(
        (m) => m.name == modeStr,
        orElse: () => ModularMode.ring,
      );

      state = state.copyWith(
        expression: data['expression'] as String? ?? '',
        modulus: data['modulus'] as String? ?? '',
        mode: mode,
        result: data['result'] as String?,
        details: data['details'] as String?,
        modulusUsed: data['modulusUsed'] as String?,
        steps: data['steps'] as String?,
        showResult: data['result'] != null,
        clearError: true,
      );
    } catch (_) {
      // Failed to restore snapshot, ignore
    }
  }
}
