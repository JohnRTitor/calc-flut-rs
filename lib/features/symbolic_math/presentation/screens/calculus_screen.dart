import 'package:flutter/material.dart';

import 'package:calc_flut_rs/features/symbolic_math/domain/symbolic_operation.dart';
import 'package:calc_flut_rs/features/symbolic_math/presentation/providers/symbolic_workspace.dart';
import '../widgets/symbolic_workspace_scaffold.dart';
/// The Calculus workspace: differentiate an expression.
///
/// Sibling of the Algebra workspace rather than a mode inside it: calculus is a
/// distinct operation family, and the Symbolic Math section already reserves a
/// card for it. Layout, timing and the result surface all come from
/// [SymbolicWorkspaceScaffold].
class CalculusScreen extends StatelessWidget {
  const CalculusScreen({super.key});

  @override
  Widget build(BuildContext context) => SymbolicWorkspaceScaffold(
    title: 'Calculus',
    hintText: 'x^2*sin(x)',
    provider: calculusProvider,
    operations: SymbolicOperation.calculusOperations,
  );
}
