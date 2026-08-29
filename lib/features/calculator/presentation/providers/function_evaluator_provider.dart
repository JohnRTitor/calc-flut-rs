import 'dart:convert';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:calc_flut_rs/features/calculator/presentation/providers/function_evaluator_state.dart';
import 'package:calc_flut_rs/generated/rust/bridge/calculator.dart'
    as rust;
import 'package:calc_flut_rs/generated/rust/bridge/history.dart'
    as rust_history;
import 'package:calc_flut_rs/features/history/presentation/providers/history_provider.dart';

part 'function_evaluator_provider.g.dart';

@riverpod
class FunctionEvaluator extends _$FunctionEvaluator {
  @override
  FunctionEvaluatorState build() {
    return const FunctionEvaluatorState();
  }

  void setExpression(String text) {
    state = state.copyWith(
      funcExpression: text,
      clearError: true,
      clearExactResult: true,
      showResult: false,
    );
    _updateDetectedVariables();
    _updatePreview();
  }

  void setVariable(String name, double value) {
    final newVars = Map<String, double>.from(state.variables);
    newVars[name] = value;
    state = state.copyWith(variables: newVars);
    _updatePreview();
  }

  void _updateDetectedVariables() {
    if (state.funcExpression.isEmpty) {
      if (state.detectedVariables.isNotEmpty) {
        state = state.copyWith(detectedVariables: const []);
      }
      return;
    }
    try {
      final vars = rust.extractVariables(expression: state.evaluatedExpression);
      state = state.copyWith(detectedVariables: vars);
    } catch (_) {
      // Ignore parsing errors while typing
    }
  }

  void _updatePreview() {
    if (state.funcExpression.isEmpty) {
      state = state.copyWith(preview: '');
      return;
    }
    try {
      final res = rust.evaluateWithVars(
        expression: state.evaluatedExpression,
        vars: state.variables,
        isDegree: state.isDegreeMode,
        ansValue: state.ansValue,
      );

      state = state.copyWith(preview: res.formatted, clearError: true);
    } catch (e) {
      state = state.copyWith(preview: '', clearError: true);
    }
  }

  Future<bool> evaluate() async {
    if (state.showResult) {
      if (state.exactResult != null) {
        toggleDisplayFormat();
        return true;
      }
      return false;
    }

    if (state.funcExpression.isEmpty) return false;

    try {
      final res = rust.evaluateWithVars(
        expression: state.evaluatedExpression,
        vars: state.variables,
        isDegree: state.isDegreeMode,
        ansValue: state.ansValue,
      );

      state = state.copyWith(
        result: res.formatted,
        showResult: true,
        clearError: true,
        ansValue: res.value,
        exactResult: res.exactFraction,
        displayAsFraction: res.exactFraction != null,
      );

      // Save history
      final newResult = res.exactFraction ?? res.formatted;
      
      rust_history.appHistoryAdd(
        category: 'functionEvaluator',
        preview: jsonEncode({
          'functionDefinition': 'f(x) = ...', // simplified for preview
          'expression': state.evaluatedExpression,
          'result': newResult,
        }),
        snapshot: jsonEncode({
          'funcExpression': state.funcExpression,
          'variables': state.variables,
          'isDegreeMode': state.isDegreeMode,
          'ansValue': state.ansValue,
          'result': res.formatted,
          'exactResult': res.exactFraction,
        }),
      );

      final historyNotifier = ref.read(historyProvider.notifier);
      await historyNotifier.saveHistoryToFile();
      historyNotifier.refresh();

      return true;
    } catch (e) {
      final cleanError = e
          .toString()
          .replaceAll('AnyhowException(', '')
          .replaceAll(RegExp(r'\)$'), '');

      state = state.copyWith(error: cleanError);
      return false;
    }
  }

  void toggleDisplayFormat() {
    if (state.exactResult != null) {
      state = state.copyWith(displayAsFraction: !state.displayAsFraction);
    }
  }

  void toggleAngleMode() {
    state = state.copyWith(isDegreeMode: !state.isDegreeMode);
    _updatePreview();
    if (state.showResult) {
      evaluate();
    }
  }

  void clear() {
    state = FunctionEvaluatorState(
      variables: state
          .variables, // keep variables around if user wants to use them again
    );
  }

  /// Restores the evaluator state from a history snapshot.
  void restoreSnapshot(String snapshotJson) {
    try {
      final Map<String, dynamic> data = jsonDecode(snapshotJson);
      
      final rawVars = data['variables'] as Map<String, dynamic>? ?? {};
      final vars = rawVars.map((k, v) => MapEntry(k, (v as num).toDouble()));

      state = state.copyWith(
        funcExpression: data['funcExpression'] as String? ?? '',
        variables: vars,
        isDegreeMode: data['isDegreeMode'] as bool? ?? false,
        ansValue: (data['ansValue'] as num?)?.toDouble() ?? 0.0,
        result: data['result'] as String? ?? '',
        exactResult: data['exactResult'] as String?,
        showResult: true,
        displayAsFraction: data['exactResult'] != null,
        preview: '',
        clearError: true,
      );
      _updateDetectedVariables();
    } catch (_) {
      // Failed to restore snapshot, ignore
    }
  }
}
