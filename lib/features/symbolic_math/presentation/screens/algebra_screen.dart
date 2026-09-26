import 'package:flutter/material.dart';

import 'package:calc_flut_rs/features/symbolic_math/domain/symbolic_operation.dart';
import 'package:calc_flut_rs/features/symbolic_math/presentation/providers/symbolic_workspace.dart';
import '../widgets/symbolic_workspace_scaffold.dart';

/// The Algebra workspace: simplify, expand and factor an expression.
///
/// Reached from the Symbolic Math hub. Uses [SymbolicWorkspaceScaffold] for
/// layout, timing and the shared widgets, so adding a tool to this section is a
/// registry edit rather than a new screen.
class AlgebraScreen extends StatelessWidget {
  const AlgebraScreen({super.key});

  @override
  Widget build(BuildContext context) => SymbolicWorkspaceScaffold(
    title: 'Algebra',
    hintText: '(x + 1)^2',
    provider: algebraProvider,
    operations: SymbolicOperation.algebraOperations,
  );
}
