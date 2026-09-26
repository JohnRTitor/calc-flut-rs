import 'package:calc_flut_rs/features/symbolic_math/domain/symbolic_operation.dart';

/// One representation of the current expression.
class SymbolicForm {
  /// The form's name, e.g. `Simplified` or `Expanded`.
  final String label;

  /// The expression written in that form.
  final String expression;

  const SymbolicForm({required this.label, required this.expression});
}

/// A failed symbolic operation, flattened from the bridge's error envelope.
///
/// The parts are kept apart because the UI presents them differently: the
/// message is the error, the suggestion is a quieter follow-up hint, and the
/// kind decides whether the "Learn More" limitation banner is shown.
class SymbolicFailure {
  /// Category from the backend: `input`, `unsupported`, `computation` or
  /// `too_large`.
  final String kind;

  /// The message to show, already plain English.
  final String message;

  /// An optional short follow-up hint.
  final String? suggestion;

  const SymbolicFailure({
    required this.kind,
    required this.message,
    this.suggestion,
  });

  /// Whether this is a practical size/complexity limit rather than a mistake.
  ///
  /// Limits get the app's existing "Learn More" explanation instead of a dead
  /// end, so the user learns why rather than just seeing a refusal.
  bool get isLimitation => kind == 'too_large';
}

/// The state of a symbolic workspace.
///
/// Shared by every tool in the Symbolic Math section. Which operations are
/// available is part of the state rather than a property of the screen, so the
/// enable/disable rules can be unit tested without pumping a widget, and so a
/// widget never has to be told which tool it is hosting.
class SymbolicWorkspaceState {
  /// The operations this tool offers, in presentation order.
  final List<SymbolicOperation> operations;

  /// The expression as typed.
  final String expression;

  /// Variables found in the expression, in the order the backend found them.
  final List<String> variables;

  /// The variable the next operation will act on.
  final String? selectedVariable;

  /// The operation whose result is currently shown, or `null` before the first
  /// run.
  final SymbolicOperation? operation;

  /// Every known form of the current expression, the requested one first.
  final List<SymbolicForm> forms;

  /// Index into [forms] of the form being displayed.
  final int activeFormIndex;

  /// A short qualifier shown under the primary value.
  final String? details;

  /// Step-by-step working, present only when Educational Mode is on.
  final String? steps;

  /// The last failure, or `null` when the last run succeeded.
  final SymbolicFailure? error;

  /// Whether a symbolic call is in flight.
  ///
  /// The result card keeps showing the previous value while this is `true`
  /// rather than blanking, so the screen never empties during work it is
  /// legitimately still doing.
  final bool isComputing;

  const SymbolicWorkspaceState({
    required this.operations,
    this.expression = '',
    this.variables = const [],
    this.selectedVariable,
    this.operation,
    this.forms = const [],
    this.activeFormIndex = 0,
    this.details,
    this.steps,
    this.error,
    this.isComputing = false,
  });

  /// The expression currently on display.
  String get displayValue =>
      forms.isEmpty ? '' : forms[activeFormIndex].expression;

  /// Whether any operation has produced a result.
  bool get hasResult => forms.isNotEmpty;

  /// Whether there is something to act on.
  bool get canRun => expression.trim().isNotEmpty && !isComputing;

  /// Whether switching to a different form is meaningful.
  ///
  /// One form on its own is not a choice, so the alternate-form chips stay
  /// hidden until the backend reports at least two.
  bool get hasMultipleForms => forms.length > 1;

  /// Whether [candidate] can run against the current expression.
  ///
  /// An operation that is contextually inapplicable is reported as disabled
  /// rather than hidden, so the feature's capabilities stay discoverable
  /// without any documentation.
  bool canRunOperation(SymbolicOperation candidate) {
    if (!canRun) return false;
    if (!candidate.requiresVariable) return true;
    // Factoring and differentiating need a variable, and must not silently
    // pick one when the user has more than one in play.
    return selectedVariable != null;
  }

  /// Why [candidate] is unavailable, or `null` when it is available.
  String? unavailableReason(SymbolicOperation candidate) {
    if (canRunOperation(candidate)) return null;
    if (isComputing) return 'Working on the previous result';
    if (expression.trim().isEmpty) return 'Enter an expression first';
    if (candidate.requiresVariable && selectedVariable == null) {
      // Distinguish "nothing to pick" from "not chosen yet". Counting on there
      // being several variables would claim there is no variable at all while
      // one sits listed and unselected.
      return variables.isEmpty
          ? 'This expression has no variable to act on'
          : 'Pick which variable to act on';
    }
    return null;
  }

  SymbolicWorkspaceState copyWith({
    List<SymbolicOperation>? operations,
    String? expression,
    List<String>? variables,
    String? selectedVariable,
    bool clearSelectedVariable = false,
    SymbolicOperation? operation,
    bool clearOperation = false,
    List<SymbolicForm>? forms,
    int? activeFormIndex,
    String? details,
    bool clearDetails = false,
    String? steps,
    bool clearSteps = false,
    SymbolicFailure? error,
    bool clearError = false,
    bool? isComputing,
  }) {
    return SymbolicWorkspaceState(
      operations: operations ?? this.operations,
      expression: expression ?? this.expression,
      variables: variables ?? this.variables,
      selectedVariable: clearSelectedVariable
          ? null
          : (selectedVariable ?? this.selectedVariable),
      operation: clearOperation ? null : (operation ?? this.operation),
      forms: forms ?? this.forms,
      activeFormIndex: activeFormIndex ?? this.activeFormIndex,
      details: clearDetails ? null : (details ?? this.details),
      steps: clearSteps ? null : (steps ?? this.steps),
      error: clearError ? null : (error ?? this.error),
      isComputing: isComputing ?? this.isComputing,
    );
  }
}
