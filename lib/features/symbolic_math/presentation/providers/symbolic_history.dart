import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:calc_flut_rs/features/symbolic_math/presentation/providers/equation_solver.dart';
import 'package:calc_flut_rs/features/symbolic_math/presentation/providers/symbolic_workspace.dart';

/// Reopens a stored symbolic result in whichever workspace produced it.
///
/// History entries in the symbolic category cover two different result shapes:
/// an expression rewritten by an operation, and an equation's solution set.
/// Which one a snapshot holds is decided by reading the snapshot, not by
/// pattern-matching its text — the shape of the JSON is this feature's business,
/// and the history screen should not have to know it.
void restoreSymbolicSnapshot(WidgetRef ref, String snapshot) {
  if (_isEquationSnapshot(snapshot)) {
    ref.read(equationSolverProvider.notifier).restoreSnapshot(snapshot);
  } else {
    ref.read(algebraProvider.notifier).restoreSnapshot(snapshot);
  }
}

bool _isEquationSnapshot(String snapshot) {
  try {
    final decoded = jsonDecode(snapshot);
    return decoded is Map<String, dynamic> && decoded['kind'] == 'equation';
  } catch (_) {
    // An unreadable snapshot is not this function's error to raise; the
    // workspace it is handed to decides what to do about it.
    return false;
  }
}
