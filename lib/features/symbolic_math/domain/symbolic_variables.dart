import 'package:calc_flut_rs/generated/rust/bridge/calculator.dart' as rust_calculator;

/// Finds the variables in [expression].
///
/// Returns an empty list when the text cannot be read, which is the normal case
/// mid-typing: an expression that does not parse yet simply has no chips rather
/// than showing an error the user has not finished causing.
///
/// Shared by every workspace in this section, so the "no chips until it parses"
/// rule cannot drift between tools.
List<String> detectVariables(String expression) {
  if (expression.trim().isEmpty) return const [];
  try {
    return rust_calculator.extractVariables(expression: expression);
  } catch (_) {
    return const [];
  }
}

/// The variable an operation should act on without the user choosing, or `null`
/// when the choice would be a guess.
///
/// Only auto-selects when there is no ambiguity. With several variables in play
/// the user must say which one, because differentiating with respect to `x` and
/// to `y` give different answers, and so does solving one equation for the
/// other.
String? defaultVariable(List<String> variables) =>
    variables.length == 1 ? variables.first : null;
