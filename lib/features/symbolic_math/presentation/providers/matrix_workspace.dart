import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:calc_flut_rs/features/history/domain/history_category.dart';
import 'package:calc_flut_rs/features/history/presentation/providers/history_provider.dart';
import 'package:calc_flut_rs/features/symbolic_math/presentation/providers/symbolic_workspace_state.dart';
import 'package:calc_flut_rs/features/symbolic_math/presentation/widgets/matrix_input_grid.dart';
import 'package:calc_flut_rs/generated/rust/bridge/history.dart'
    as rust_history;
import 'package:calc_flut_rs/generated/rust/bridge/symbolic.dart'
    as rust_symbolic;

/// The state of the Matrix workspace.
///
/// Separate from [SymbolicWorkspaceState] because the input is a grid rather
/// than a line of text, and the result is a fixed set of named quantities
/// rather than one expression or a solution set. Overloading either with
/// optional fields would leave every reader guessing which shape it was looking
/// at.
class MatrixState {
  /// The cells, row-major.
  final List<List<String>> cells;

  /// The analysis, once one has been produced.
  final rust_symbolic.MatrixAnalysisResponse? analysis;

  /// The last failure, or `null` when the last analysis succeeded.
  final SymbolicFailure? error;

  /// Whether an analysis is in flight.
  final bool isComputing;

  const MatrixState({
    this.cells = const [],
    this.analysis,
    this.error,
    this.isComputing = false,
  });

  /// Whether there is a matrix to analyse.
  bool get canAnalyse => !isComputing && cells.any((row) => row.isNotEmpty);

  /// Why analysing is unavailable, or `null` when it is available.
  String? unavailableReason() {
    if (canAnalyse) return null;
    if (isComputing) return 'Working on the previous result';
    return 'Enter at least one cell';
  }

  MatrixState copyWith({
    List<List<String>>? cells,
    rust_symbolic.MatrixAnalysisResponse? analysis,
    bool clearAnalysis = false,
    SymbolicFailure? error,
    bool clearError = false,
    bool? isComputing,
  }) {
    return MatrixState(
      cells: cells ?? this.cells,
      analysis: clearAnalysis ? null : (analysis ?? this.analysis),
      error: clearError ? null : (error ?? this.error),
      isComputing: isComputing ?? this.isComputing,
    );
  }
}

/// Drives the Matrix workspace.
class MatrixWorkspace extends Notifier<MatrixState> {
  @override
  MatrixState build() => MatrixState(cells: MatrixInputGrid.initialCells());

  /// Records a new grid.
  ///
  /// A previous analysis is dropped: it described the matrix that was there
  /// before, and showing it beside a new one would be answering a question
  /// nobody asked.
  void setCells(List<List<String>> cells) {
    state = state.copyWith(cells: cells, clearAnalysis: true, clearError: true);
  }

  /// Analyses the current matrix.
  ///
  /// Returns whether it succeeded. Returns `true` for a partial answer too:
  /// a singular matrix has no inverse, and that is a fact about the matrix
  /// rather than a failure.
  Future<bool> analyse() async {
    if (!state.canAnalyse) return false;

    state = state.copyWith(isComputing: true, clearError: true);
    final cellsAtRequest = state.cells;

    try {
      // Flat, with the shape alongside: the bridge cannot encode a nested
      // vector, so this is the wire format rather than a change to the data.
      final columns = cellsAtRequest.isEmpty ? 0 : cellsAtRequest.first.length;
      final result = await rust_symbolic.matrixAnalyse(
        input: rust_symbolic.MatrixInput(
          rows: cellsAtRequest.length,
          columns: columns,
          cells: [for (final row in cellsAtRequest) ...row],
        ),
      );

      // The grid may have changed while this was in flight.
      if (!_sameGrid(state.cells, cellsAtRequest)) {
        state = state.copyWith(isComputing: false);
        return false;
      }

      state = state.copyWith(
        analysis: result,
        clearError: true,
        isComputing: false,
      );
      _recordHistory(result, cellsAtRequest);
      return true;
    } catch (error) {
      state = state.copyWith(isComputing: false, error: _toFailure(error));
      return false;
    }
  }

  /// Reopens a stored matrix.
  ///
  /// The cells come back, but not the analysis: it is a line of display text
  /// derived from a computation this provider can run again, and restoring a
  /// stale rendering of it would show numbers that may no longer follow from
  /// what is on screen.
  void restoreSnapshot(String snapshot) {
    try {
      final decoded = jsonDecode(snapshot);
      if (decoded is! Map<String, dynamic>) return;
      final raw = decoded['cells'];
      if (raw is! List) return;
      final cells = <List<String>>[];
      for (final row in raw) {
        if (row is! List) return;
        cells.add([for (final cell in row) cell?.toString() ?? '']);
      }
      if (cells.isEmpty || cells.any((row) => row.isEmpty)) return;
      // Rows of differing lengths do not describe a matrix. Taking them on would
      // only defer the complaint to the bridge, and the grid would show a shape
      // that cannot be analysed.
      final width = cells.first.length;
      if (cells.any((row) => row.length != width)) return;
      state = MatrixState(cells: cells);
    } catch (_) {
      // An unreadable snapshot leaves the workspace as it was, rather than
      // clearing a grid the user may have been working in.
    }
  }

  /// Adds the analysis to the shared, cross-feature history timeline.
  void _recordHistory(
    rust_symbolic.MatrixAnalysisResponse result,
    List<List<String>> cells,
  ) {
    final matrix = cells.map((row) => '[${row.join(', ')}]').join(', ');
    rust_history.appHistoryAdd(
      category: HistoryCategory.symbolic.name,
      preview: jsonEncode({
        'operation': 'Matrices',
        'expression': matrix,
        'result': _summary(result),
      }),
      snapshot: jsonEncode({'kind': 'matrix', 'cells': cells}),
    );

    final history = ref.read(historyProvider.notifier);
    history.saveHistoryToFile();
  }

  /// A one-line statement of the headline facts, for the history list.
  ///
  /// Only quantities that exist are named, so a singular matrix does not get
  /// "det 0" attached to a determinant that was never defined for it.
  String _summary(rust_symbolic.MatrixAnalysisResponse result) {
    final parts = <String>['rank ${result.rank}'];
    if (result.determinant != null) parts.add('det ${result.determinant}');
    if (result.trace != null) parts.add('trace ${result.trace}');
    final eigenvalues = result.eigenvalues;
    if (eigenvalues != null && eigenvalues.isNotEmpty) {
      parts.add('eigenvalues ${eigenvalues.join(', ')}');
    }
    return parts.join(', ');
  }

  bool _sameGrid(List<List<String>> a, List<List<String>> b) {
    if (a.length != b.length) return false;
    for (var r = 0; r < a.length; r++) {
      if (a[r].length != b[r].length) return false;
      for (var c = 0; c < a[r].length; c++) {
        if (a[r][c] != b[r][c]) return false;
      }
    }
    return true;
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
      message: 'Something went wrong while working on that matrix',
    );
  }
}

/// The Matrix workspace.
final matrixProvider = NotifierProvider<MatrixWorkspace, MatrixState>(
  MatrixWorkspace.new,
);
