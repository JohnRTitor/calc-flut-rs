import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:calc_flut_rs/features/symbolic_math/presentation/providers/equation_solver.dart';
import 'package:calc_flut_rs/features/symbolic_math/presentation/providers/matrix_workspace.dart';
import 'package:calc_flut_rs/features/symbolic_math/presentation/providers/number_theory_workspace.dart';
import 'package:calc_flut_rs/features/symbolic_math/presentation/providers/symbolic_workspace.dart';

/// Reopens a stored symbolic result in whichever workspace produced it.
///
/// History entries in the symbolic category span several result shapes: an
/// expression rewritten by an operation, an equation's solution set, a matrix
/// analysis, and a single number's properties. Which one a snapshot holds is
/// decided by reading the snapshot, not by pattern-matching its text — the shape
/// of the JSON is this feature's business, and the history screen should not
/// have to know it.
void restoreSymbolicSnapshot(WidgetRef ref, String snapshot) {
  switch (_kindOf(snapshot)) {
    case 'equation':
      ref.read(equationSolverProvider.notifier).restoreSnapshot(snapshot);
    case 'matrix':
      ref.read(matrixProvider.notifier).restoreSnapshot(snapshot);
    case 'number_theory':
      ref.read(numberTheoryProvider.notifier).restoreSnapshot(snapshot);
    // An expression result, and anything unreadable. The algebra workspace owns
    // the fallback because it is the original symbolic workspace, and it
    // ignores a snapshot it cannot read rather than clearing what is on screen.
    default:
      ref.read(algebraProvider.notifier).restoreSnapshot(snapshot);
  }
}

/// The `kind` a snapshot declares, or `null` if it declares none.
String? _kindOf(String snapshot) {
  try {
    final decoded = jsonDecode(snapshot);
    if (decoded is Map<String, dynamic>) {
      final kind = decoded['kind'];
      return kind is String ? kind : null;
    }
    return null;
  } catch (_) {
    // An unreadable snapshot is not this function's error to raise; the
    // workspace it is handed to decides what to do about it.
    return null;
  }
}
