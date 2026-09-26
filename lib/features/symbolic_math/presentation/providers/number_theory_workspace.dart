import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:calc_flut_rs/features/history/domain/history_category.dart';
import 'package:calc_flut_rs/features/history/presentation/providers/history_provider.dart';
import 'package:calc_flut_rs/features/symbolic_math/presentation/providers/symbolic_workspace_state.dart';
import 'package:calc_flut_rs/generated/rust/bridge/history.dart'
    as rust_history;
import 'package:calc_flut_rs/generated/rust/bridge/symbolic.dart'
    as rust_symbolic;

/// The state of the Number Theory workspace.
///
/// One integer analysed in a single pass, so every fact about it arrives
/// together rather than one per tap.
class NumberTheoryState {
  /// The number as typed.
  final String number;

  /// A second number, for the two-input operations.
  final String other;

  /// The analysis of [number], once produced.
  final rust_symbolic.NumberAnalysisResponse? analysis;

  /// The greatest common divisor of [number] and [other], once asked for.
  final String? gcd;

  /// The least common multiple of [number] and [other], once asked for.
  final String? lcm;

  /// Whether [number] and [other] share no factor other than 1.
  ///
  /// `null` until asked, since it is a yes/no question rather than a value.
  final bool? coprime;

  /// The last failure, or `null` when the last call succeeded.
  final SymbolicFailure? error;

  /// Whether a call is in flight.
  final bool isComputing;

  const NumberTheoryState({
    this.number = '',
    this.other = '',
    this.analysis,
    this.gcd,
    this.lcm,
    this.coprime,
    this.error,
    this.isComputing = false,
  });

  /// Whether there is a number to work on.
  bool get canAnalyse => number.trim().isNotEmpty && !isComputing;

  /// Whether both numbers are present, which the pair operations need.
  bool get canCompare => canAnalyse && other.trim().isNotEmpty;

  /// Whether the pair results are on screen, so they can be cleared.
  bool get hasPairResult => gcd != null || lcm != null || coprime != null;

  NumberTheoryState copyWith({
    String? number,
    String? other,
    rust_symbolic.NumberAnalysisResponse? analysis,
    bool clearAnalysis = false,
    String? gcd,
    bool clearGcd = false,
    String? lcm,
    bool clearLcm = false,
    bool? coprime,
    bool clearCoprime = false,
    SymbolicFailure? error,
    bool clearError = false,
    bool? isComputing,
  }) {
    return NumberTheoryState(
      number: number ?? this.number,
      other: other ?? this.other,
      analysis: clearAnalysis ? null : (analysis ?? this.analysis),
      gcd: clearGcd ? null : (gcd ?? this.gcd),
      lcm: clearLcm ? null : (lcm ?? this.lcm),
      coprime: clearCoprime ? null : (coprime ?? this.coprime),
      error: clearError ? null : (error ?? this.error),
      isComputing: isComputing ?? this.isComputing,
    );
  }
}

/// Drives the Number Theory workspace.
class NumberTheoryWorkspace extends Notifier<NumberTheoryState> {
  @override
  NumberTheoryState build() => const NumberTheoryState();

  /// Records a new number, dropping results that described the previous one.
  void setNumber(String number) {
    state = state.copyWith(
      number: number,
      clearAnalysis: true,
      clearError: true,
      // The pair results involve both numbers, so they go too.
      clearGcd: true,
      clearLcm: true,
      clearCoprime: true,
    );
  }

  /// Records the second number for the pair operations.
  void setOther(String other) {
    state = state.copyWith(
      other: other,
      clearError: true,
      clearGcd: true,
      clearLcm: true,
      clearCoprime: true,
    );
  }

  /// Analyses the current number.
  Future<bool> analyse() async {
    if (!state.canAnalyse) return false;

    state = state.copyWith(isComputing: true, clearError: true);
    final numberAtRequest = state.number;

    try {
      final result = await rust_symbolic.numberAnalyse(number: numberAtRequest);
      if (state.number != numberAtRequest) {
        state = state.copyWith(isComputing: false);
        return false;
      }
      state = state.copyWith(
        analysis: result,
        clearError: true,
        isComputing: false,
      );
      _recordHistory(result, numberAtRequest);
      return true;
    } catch (error) {
      state = state.copyWith(isComputing: false, error: _toFailure(error));
      return false;
    }
  }

  /// Reopens a stored number.
  ///
  /// As with the matrix, the analysis is not restored: it is display text from
  /// a computation this provider can run again, and a stale rendering beside a
  /// freshly typed number would be an answer to a question nobody asked.
  void restoreSnapshot(String snapshot) {
    try {
      final decoded = jsonDecode(snapshot);
      if (decoded is! Map<String, dynamic>) return;
      final number = decoded['number']?.toString();
      if (number == null || number.isEmpty) return;
      state = NumberTheoryState(number: number);
    } catch (_) {
      // An unreadable snapshot leaves the workspace as it was, rather than
      // clearing a number the user may have been working with.
    }
  }

  /// Adds the analysis to the shared, cross-feature history timeline.
  void _recordHistory(
    rust_symbolic.NumberAnalysisResponse result,
    String number,
  ) {
    rust_history.appHistoryAdd(
      category: HistoryCategory.symbolic.name,
      preview: jsonEncode({
        'operation': 'Number Theory',
        'expression': number,
        'result': _summary(result),
      }),
      snapshot: jsonEncode({'kind': 'number_theory', 'number': number}),
    );

    final history = ref.read(historyProvider.notifier);
    history.saveHistoryToFile();
  }

  /// A one-line statement of the headline facts, for the history list.
  ///
  /// The factorisation leads, since that is what the tool is usually opened
  /// for. A number with no factorisation says so rather than reporting an empty
  /// product, which would read as 1.
  String _summary(rust_symbolic.NumberAnalysisResponse result) {
    if (result.isPrime) return 'prime';
    final factors = result.factors;
    if (factors.isNotEmpty) {
      return factors
          .map((f) => f.power == 1 ? f.prime : '${f.prime}^${f.power}')
          .join(' * ');
    }
    return result.details ?? 'no factorisation';
  }

  /// Computes the greatest common divisor of the two numbers.
  Future<bool> compareGcd() async {
    if (!state.canCompare) return false;

    state = state.copyWith(isComputing: true, clearError: true);
    final (a, b) = (state.number, state.other);
    try {
      final value = await rust_symbolic.numberGcd(first: a, second: b);
      if (state.number != a || state.other != b) {
        state = state.copyWith(isComputing: false);
        return false;
      }
      state = state.copyWith(gcd: value, clearError: true, isComputing: false);
      return true;
    } catch (error) {
      state = state.copyWith(isComputing: false, error: _toFailure(error));
      return false;
    }
  }

  /// Computes the least common multiple of the two numbers.
  Future<bool> compareLcm() async {
    if (!state.canCompare) return false;

    state = state.copyWith(isComputing: true, clearError: true);
    final (a, b) = (state.number, state.other);
    try {
      final value = await rust_symbolic.numberLcm(first: a, second: b);
      if (state.number != a || state.other != b) {
        state = state.copyWith(isComputing: false);
        return false;
      }
      state = state.copyWith(lcm: value, clearError: true, isComputing: false);
      return true;
    } catch (error) {
      state = state.copyWith(isComputing: false, error: _toFailure(error));
      return false;
    }
  }

  /// Asks whether the two numbers are coprime.
  Future<bool> compareCoprime() async {
    if (!state.canCompare) return false;

    state = state.copyWith(isComputing: true, clearError: true);
    final (a, b) = (state.number, state.other);
    try {
      final value = await rust_symbolic.numberCoprime(first: a, second: b);
      if (state.number != a || state.other != b) {
        state = state.copyWith(isComputing: false);
        return false;
      }
      state = state.copyWith(
        coprime: value,
        clearError: true,
        isComputing: false,
      );
      return true;
    } catch (error) {
      state = state.copyWith(isComputing: false, error: _toFailure(error));
      return false;
    }
  }

  SymbolicFailure _toFailure(Object error) {
    if (error is rust_symbolic.SymbolicErrorInfo) {
      return SymbolicFailure(
        kind: error.kind,
        message: error.message,
        suggestion: error.suggestion,
      );
    }
    return const SymbolicFailure(
      kind: 'computation',
      message: 'Something went wrong while working on that number',
    );
  }
}

/// The Number Theory workspace.
final numberTheoryProvider =
    NotifierProvider<NumberTheoryWorkspace, NumberTheoryState>(
      NumberTheoryWorkspace.new,
    );
