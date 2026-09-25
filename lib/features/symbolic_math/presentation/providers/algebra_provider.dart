import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:calc_flut_rs/features/history/presentation/providers/history_provider.dart';
import 'package:calc_flut_rs/features/settings/presentation/providers/settings_provider.dart';
import 'package:calc_flut_rs/features/symbolic_math/presentation/providers/algebra_state.dart';
import 'package:calc_flut_rs/generated/rust/bridge/calculator.dart' as rust_calculator;
import 'package:calc_flut_rs/generated/rust/bridge/history.dart' as rust_history;
import 'package:calc_flut_rs/generated/rust/bridge/symbolic.dart' as rust_symbolic;

part 'algebra_provider.g.dart';

/// Drives the Algebra workspace.
///
/// Every symbolic call goes through the async bridge, so no method here blocks
/// the UI thread: the numeric calculator's synchronous fast path is untouched
/// and unaffected by this feature.
@riverpod
class Algebra extends _$Algebra {
  @override
  AlgebraState build() => const AlgebraState();

  /// Records a new expression and re-detects its variables.
  ///
  /// Variable detection is the existing synchronous helper, which is cheap: it
  /// only scans for names, it does not evaluate anything.
  void setExpression(String expression) {
    state = state.copyWith(
      expression: expression,
      clearError: true,
      // A result belongs to the expression that produced it. Keeping it would
      // show an answer to a question that is no longer being asked.
      clearOperation: true,
      clearSelectedVariable: true,
      forms: const [],
      activeFormIndex: 0,
      clearDetails: true,
      clearSteps: true,
    );
    _refreshVariables();
  }

  /// Re-scans the expression for variables and picks a sensible default.
  void _refreshVariables() {
    if (state.expression.trim().isEmpty) {
      state = state.copyWith(variables: const [], clearSelectedVariable: true);
      return;
    }

    try {
      final variables = rust_calculator.extractVariables(
        expression: state.expression,
      );
      final selected = _defaultVariable(variables);
      state = state.copyWith(
        variables: variables,
        selectedVariable: selected,
        clearSelectedVariable: selected == null,
      );
    } catch (_) {
      // Mid-typing input is expected to be unparseable; show no chips until
      // it parses rather than flashing an error.
      state = state.copyWith(variables: const [], clearSelectedVariable: true);
    }
  }

  /// Chooses the variable an operation should act on without the user choosing.
  ///
  /// Only auto-selects when there is no ambiguity: with several variables in
  /// play the user must say which one, because factoring with respect to `x` and
  /// with respect to `y` give different answers.
  String? _defaultVariable(List<String> variables) {
    if (variables.length == 1) return variables.first;
    return null;
  }

  /// Sets the variable the next operation acts on.
  void selectVariable(String variable) {
    state = state.copyWith(selectedVariable: variable, clearError: true);
  }

  /// Shows a different known form of the current expression.
  ///
  /// Purely local: every form was computed in the same bridge call, so
  /// switching costs no round trip and cannot fail.
  void showForm(int index) {
    if (index < 0 || index >= state.forms.length) return;
    state = state.copyWith(activeFormIndex: index);
  }

  /// Resets to an empty workspace.
  void clear() {
    state = const AlgebraState();
  }

  /// Restores a previously computed result from a history snapshot.
  ///
  /// The stored forms are reinstated rather than recomputed, so opening a past
  /// entry shows the answer the user actually tapped on. A snapshot that no
  /// longer parses is ignored, leaving the workspace empty rather than
  /// half-populated.
  void restoreSnapshot(String snapshotJson) {
    try {
      final data = jsonDecode(snapshotJson);
      if (data is! Map<String, dynamic>) return;

      final expression = data['expression'];
      if (expression is! String) return;

      final wireName = data['operation'];
      final operation = wireName is String
          ? AlgebraOperation.values.where((o) => o.wireName == wireName).firstOrNull
          : null;

      final rawForms = data['forms'];
      final forms = rawForms is List
          ? rawForms
                .whereType<Map<String, dynamic>>()
                .map(
                  (form) => AlgebraForm(
                    label: form['label']?.toString() ?? '',
                    expression: form['expression']?.toString() ?? '',
                  ),
                )
                .where((form) => form.label.isNotEmpty && form.expression.isNotEmpty)
                .toList()
          : <AlgebraForm>[];

      state = AlgebraState(
        expression: expression,
        operation: operation,
        forms: forms,
        selectedVariable: data['variable']?.toString(),
        details: data['details']?.toString(),
        steps: data['steps']?.toString(),
      );
      _refreshVariables();
    } catch (_) {
      // A snapshot from an older schema is not worth failing over.
    }
  }

  /// Runs [operation] against the current expression.
  ///
  /// Returns whether the operation succeeded, matching the convention used by
  /// the other workspaces' primary actions.
  Future<bool> run(AlgebraOperation operation) async {
    if (!state.canRunOperation(operation)) return false;

    state = state.copyWith(isComputing: true, clearError: true);

    final expressionAtRequest = state.expression;
    final variableAtRequest = state.selectedVariable;

    try {
      final showSteps = ref.read(educationalModeProvider);

      final result = await rust_symbolic.symbolicTransform(
        expression: expressionAtRequest,
        operation: operation.wireName,
        variable: operation.requiresVariable ? variableAtRequest : null,
        showSteps: showSteps,
      );

      // The user may have kept typing while this was in flight. A result that
      // answers a different expression must not replace what is on screen.
      if (state.expression != expressionAtRequest) {
        state = state.copyWith(isComputing: false);
        return false;
      }

      final forms = <AlgebraForm>[
        AlgebraForm(label: '${operation.label}ed', expression: result.value),
        ...result.alternateForms.map(
          (form) => AlgebraForm(
            label: form.label,
            expression: form.expression,
          ),
        ),
      ];

      state = state.copyWith(
        operation: operation,
        forms: forms,
        activeFormIndex: 0,
        details: result.details,
        steps: result.steps,
        clearError: true,
        isComputing: false,
      );

      _recordHistory(operation, result.value);

      return true;
    } catch (error) {
      state = state.copyWith(
        isComputing: false,
        error: _toAlgebraError(error),
        // The previous result stays on screen: it is still the last thing the
        // backend actually computed for this expression.
        clearSteps: true,
      );
      return false;
    }
  }

  /// Flattens the bridge's typed error envelope into display state.
  ///
  /// The backend sends a structured error, so the common path needs no string
  /// handling at all. The fallback exists only for failures raised outside the
  /// call itself, and deliberately does not try to parse wrapper syntax.
  AlgebraError _toAlgebraError(Object error) {
    if (error is rust_symbolic.SymbolicErrorInfo) {
      return AlgebraError(
        kind: error.kind,
        message: error.message,
        suggestion: error.suggestion,
      );
    }
    return const AlgebraError(
      kind: 'computation',
      message: 'Something went wrong while working on that expression',
    );
  }

  /// Adds the result to the shared, cross-feature history timeline.
  void _recordHistory(AlgebraOperation operation, String result) {
    rust_history.appHistoryAdd(
      category: 'symbolic',
      preview: jsonEncode({
        'operation': operation.label,
        'expression': state.expression,
        'result': result,
      }),
      snapshot: jsonEncode({
        'expression': state.expression,
        'operation': operation.wireName,
        'variable': state.selectedVariable,
        'forms': state.forms
            .map((form) => {'label': form.label, 'expression': form.expression})
            .toList(),
        'details': state.details,
        'steps': state.steps,
      }),
    );

    final history = ref.read(historyProvider.notifier);
    history.saveHistoryToFile();
    history.refresh();
  }
}
