import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:calc_flut_rs/features/history/domain/history_category.dart';
import 'package:calc_flut_rs/features/history/presentation/providers/history_provider.dart';
import 'package:calc_flut_rs/features/settings/presentation/providers/settings_provider.dart';
import 'package:calc_flut_rs/features/symbolic_math/domain/symbolic_variables.dart';
import 'package:calc_flut_rs/features/symbolic_math/presentation/providers/equation_solver_state.dart';
import 'package:calc_flut_rs/features/symbolic_math/presentation/providers/symbolic_workspace_state.dart';
import 'package:calc_flut_rs/generated/rust/bridge/history.dart' as rust_history;
import 'package:calc_flut_rs/generated/rust/bridge/symbolic.dart' as rust_symbolic;

/// Drives the Equation Solver: an equation in, its solution set out.
///
/// Separate from [SymbolicWorkspace] because the result is a set of solutions
/// rather than one expression, and a solution set does not fit the form/transform
/// model that state is built around. The expression-and-variable bookkeeping is
/// shared through `symbolic_variables.dart` rather than copied.
class EquationSolver extends Notifier<EquationSolverState> {
  @override
  EquationSolverState build() => const EquationSolverState();

  /// Records a new equation and re-detects its variables.
  void setEquation(String equation) {
    state = state.copyWith(
      equation: equation,
      clearError: true,
      // A result belongs to the equation that produced it.
      clearSelectedVariable: true,
      clearSolutionKind: true,
      solutions: const [],
      clearDetails: true,
      clearSteps: true,
    );
    _refreshVariables();
  }

  void _refreshVariables() {
    final variables = detectVariables(state.equation);
    final selected = defaultVariable(variables);
    state = state.copyWith(
      variables: variables,
      selectedVariable: selected,
      clearSelectedVariable: selected == null,
    );
  }

  /// Sets the variable to solve for.
  void selectVariable(String variable) {
    state = state.copyWith(selectedVariable: variable, clearError: true);
  }

  /// Resets to an empty workspace.
  void clear() => state = const EquationSolverState();

  /// Solves the current equation.
  ///
  /// Returns whether the solve succeeded. Note that a "no solution" or
  /// "infinitely many" answer counts as success: they are answers, and are
  /// reported through [EquationSolverState.solutionKind] rather than as
  /// failures.
  Future<bool> solve() async {
    if (!state.canRun) return false;

    state = state.copyWith(isComputing: true, clearError: true);
    final equationAtRequest = state.equation;
    final variableAtRequest = state.selectedVariable;

    try {
      final showSteps = ref.read(educationalModeProvider);

      final result = await rust_symbolic.symbolicSolve(
        equation: equationAtRequest,
        variable: variableAtRequest,
        showSteps: showSteps,
      );

      // The user may have kept typing while this was in flight.
      if (state.equation != equationAtRequest) {
        state = state.copyWith(isComputing: false);
        return false;
      }

      state = state.copyWith(
        solutions: result.solutions,
        solutionKind: result.solutionKind,
        details: result.details,
        steps: result.steps,
        clearError: true,
        isComputing: false,
      );

      _recordHistory(result);
      return true;
    } catch (error) {
      state = state.copyWith(
        isComputing: false,
        error: _toFailure(error),
        clearSteps: true,
      );
      return false;
    }
  }

  /// Flattens the bridge's typed error envelope into display state.
  SymbolicFailure? _toFailure(Object error) {
    if (error is rust_symbolic.SymbolicErrorInfo) {
      return SymbolicFailure(
        kind: error.kind,
        message: error.message,
        suggestion: error.suggestion,
      );
    }
    return const SymbolicFailure(
      kind: 'computation',
      message: 'Something went wrong while solving that equation',
    );
  }

  /// Adds the result to the shared, cross-feature history timeline.
  void _recordHistory(rust_symbolic.SymbolicSolveResult result) {
    final kind = result.solutionKind;
    rust_history.appHistoryAdd(
      category: HistoryCategory.symbolic.name,
      preview: jsonEncode({
        'operation': 'Solve',
        'expression': state.equation,
        'result': result.solutions.isEmpty ? (kind.name) : result.solutions.join(', '),
      }),
      snapshot: jsonEncode({
        'kind': 'equation',
        'equation': state.equation,
        'variable': state.selectedVariable,
        'solutions': result.solutions,
        'solutionKind': kind.name,
        'details': result.details,
        'steps': result.steps,
      }),
    );

    final history = ref.read(historyProvider.notifier);
    history.saveHistoryToFile();
    history.refresh();
  }

  /// Restores a previously solved equation from a history snapshot.
  void restoreSnapshot(String snapshotJson) {
    try {
      final data = jsonDecode(snapshotJson);
      if (data is! Map<String, dynamic>) return;
      if (data['kind'] != 'equation') return;

      final equation = data['equation'];
      if (equation is! String) return;

      final kindName = data['solutionKind'];
      final kind = kindName is String
          ? rust_symbolic.SolutionKind.values
                .where((candidate) => candidate.name == kindName)
                .firstOrNull
          : null;

      final rawSolutions = data['solutions'];
      state = EquationSolverState(
        equation: equation,
        solutions: rawSolutions is List
            ? rawSolutions.map((s) => s.toString()).toList()
            : const [],
        solutionKind: kind,
        selectedVariable: data['variable']?.toString(),
        details: data['details']?.toString(),
        steps: data['steps']?.toString(),
      );
      _refreshVariables();
    } catch (_) {
      // A snapshot from an older schema is not worth failing over.
    }
  }
}

/// The Equation Solver workspace.
final equationSolverProvider =
    NotifierProvider<EquationSolver, EquationSolverState>(EquationSolver.new);
