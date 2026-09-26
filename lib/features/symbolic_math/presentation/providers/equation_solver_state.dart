import 'package:calc_flut_rs/features/symbolic_math/presentation/providers/symbolic_workspace_state.dart';
import 'package:calc_flut_rs/generated/rust/bridge/symbolic.dart' as rust_symbolic;

/// The state of the Equation Solver workspace.
///
/// A separate type from [SymbolicWorkspaceState] because the result is a
/// solution set rather than one expression. Overloading the expression result
/// with optional fields would leave every caller guessing which combination it
/// was looking at, so the two shapes stay apart.
class EquationSolverState {
  /// The equation as typed, `=` included.
  final String equation;

  /// Variables found in the equation, in the order the backend found them.
  final List<String> variables;

  /// The variable the solver is solving for.
  ///
  /// With more than one variable in the equation there is no single right
  /// answer, so the user has to say which one rather than have one picked.
  final String? selectedVariable;

  /// The verified solutions, empty unless [solutionKind] reports a finite set.
  final List<String> solutions;

  /// Which of the four mathematical outcomes this is.
  final rust_symbolic.SolutionKind? solutionKind;

  /// A short qualifier, e.g. that candidate roots were discarded.
  final String? details;

  /// Step-by-step working, present only when Educational Mode is on.
  final String? steps;

  /// The last failure, or `null` when the last solve succeeded.
  ///
  /// Only ever a genuine failure: "no solution" and "infinitely many" are
  /// answers, and arrive as [solutionKind] rather than here.
  final SymbolicFailure? error;

  /// Whether a solve is in flight.
  final bool isComputing;

  const EquationSolverState({
    this.equation = '',
    this.variables = const [],
    this.selectedVariable,
    this.solutions = const [],
    this.solutionKind,
    this.details,
    this.steps,
    this.error,
    this.isComputing = false,
  });

  /// Whether an equation has been solved.
  bool get hasResult => solutionKind != null;

  /// Whether there is something to solve.
  bool get canSolve => equation.trim().isNotEmpty && !isComputing;

  /// Whether the solver has been given a variable to work with.
  bool get canRun => canSolve && selectedVariable != null;

  /// Why solving is unavailable, or `null` when it is available.
  String? unavailableReason() {
    if (canRun) return null;
    if (isComputing) return 'Working on the previous result';
    if (equation.trim().isEmpty) return 'Enter an equation first';
    if (selectedVariable == null) {
      return variables.isEmpty
          ? 'This equation has no variable to solve for'
          : 'Pick which variable to solve for';
    }
    return null;
  }

  /// Whether the outcome is a finite list of more than one solution.
  bool get hasMultipleSolutions =>
      solutionKind == rust_symbolic.SolutionKind.multiple;

  /// Whether every value works.
  ///
  /// A correct answer, so it is presented as a result rather than as a failure.
  bool get isInfinite => solutionKind == rust_symbolic.SolutionKind.infinite;

  /// Whether nothing satisfies the equation.
  ///
  /// Also a correct answer, not a mistake by the user and not a failure.
  bool get hasNoSolution => solutionKind == rust_symbolic.SolutionKind.none;

  EquationSolverState copyWith({
    String? equation,
    List<String>? variables,
    String? selectedVariable,
    bool clearSelectedVariable = false,
    List<String>? solutions,
    rust_symbolic.SolutionKind? solutionKind,
    bool clearSolutionKind = false,
    String? details,
    bool clearDetails = false,
    String? steps,
    bool clearSteps = false,
    SymbolicFailure? error,
    bool clearError = false,
    bool? isComputing,
  }) {
    return EquationSolverState(
      equation: equation ?? this.equation,
      variables: variables ?? this.variables,
      selectedVariable: clearSelectedVariable
          ? null
          : (selectedVariable ?? this.selectedVariable),
      solutions: solutions ?? this.solutions,
      solutionKind: clearSolutionKind
          ? null
          : (solutionKind ?? this.solutionKind),
      details: clearDetails ? null : (details ?? this.details),
      steps: clearSteps ? null : (steps ?? this.steps),
      error: clearError ? null : (error ?? this.error),
      isComputing: isComputing ?? this.isComputing,
    );
  }
}
