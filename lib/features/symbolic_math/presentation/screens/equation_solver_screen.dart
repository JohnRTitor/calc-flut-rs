import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:calc_flut_rs/features/settings/presentation/providers/theme_provider.dart';
import 'package:calc_flut_rs/features/symbolic_math/presentation/providers/equation_solver.dart';
import 'package:calc_flut_rs/features/symbolic_math/presentation/widgets/symbolic_expression_editor.dart';
import 'package:calc_flut_rs/features/symbolic_math/presentation/widgets/symbolic_solve_result_card.dart';
import 'package:calc_flut_rs/features/symbolic_math/presentation/widgets/symbolic_help_dialog.dart';
import 'package:calc_flut_rs/features/symbolic_math/presentation/widgets/symbolic_workspace_scaffold.dart';
import 'package:calc_flut_rs/shared/widgets/app_notice.dart';
import 'package:calc_flut_rs/shared/widgets/symbolic_primary_action.dart';

/// The Equation Solver workspace: solve an equation for one variable.
///
/// A sibling of the Algebra and Calculus workspaces rather than a mode inside
/// them, because the result is a *set* of solutions rather than one expression.
/// It reuses their editor, variable selector and computing feedback, and has its
/// own result surface for the four solution outcomes.
class EquationSolverScreen extends ConsumerStatefulWidget {
  const EquationSolverScreen({super.key});

  @override
  ConsumerState<EquationSolverScreen> createState() =>
      _EquationSolverScreenState();
}

class _EquationSolverScreenState extends ConsumerState<EquationSolverScreen> {
  /// Whether a solve is slow enough to admit.
  bool _solveIsSlow = false;

  Timer? _indicatorTimer;
  Timer? _slowCallTimer;

  @override
  void dispose() {
    _indicatorTimer?.cancel();
    _slowCallTimer?.cancel();
    super.dispose();
  }

  /// Solves the equation, showing feedback only if it turns out to be slow.
  Future<void> _solve() async {
    _indicatorTimer?.cancel();
    _slowCallTimer?.cancel();
    setState(() => _solveIsSlow = false);

    _indicatorTimer = Timer(SymbolicComputeTimings.indicatorDelay, () {
      if (!mounted) return;
      setState(() => _solveIsSlow = true);
    });
    _slowCallTimer = Timer(SymbolicComputeTimings.slowCallNotice, () {
      if (!mounted) return;
      setState(() => _solveIsSlow = true);
    });

    final succeeded = await ref.read(equationSolverProvider.notifier).solve();

    _indicatorTimer?.cancel();
    _slowCallTimer?.cancel();
    if (!mounted) return;
    setState(() => _solveIsSlow = false);
    FocusScope.of(context).unfocus();

    // "No solution" and "infinitely many" are answers, so a successful solve
    // that produced neither solutions nor a failure says nothing.
    if (!succeeded && mounted) {
      final error = ref.read(equationSolverProvider).error;
      if (error != null) {
        showAppNotice(context, error.message, icon: Icons.error_outline);
      }
    }
  }

  void _showHelp() {
    showSymbolicHelpDialog(
      context: context,
      uiStyle: ref.read(uiStyleProvider),
      title: 'Equation Solving',
      description:
          'Enter an equation with a single "=" and pick the variable to solve '
          'for. Every candidate the solver finds is substituted back into your '
          'equation and checked, so a root that only satisfies a rearranged '
          'form is discarded rather than shown.',
      notes: const [
        'An equation can have one solution, several, every value, or none — all '
            'four are answers, and none of them is an error.',
        'Complex roots are shown as i, so x² = −1 reports x = i and x = −i.',
        'Solutions stay exact: 1/3 rather than 0.333, sqrt(2) rather than 1.41.',
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(equationSolverProvider);
    final uiStyle = ref.watch(uiStyleProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Equation Solver')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (!constraints.hasBoundedHeight || constraints.maxHeight <= 0) {
            return const SizedBox.shrink();
          }

          return SingleChildScrollView(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 8,
              bottom: 16 + MediaQuery.paddingOf(context).bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SymbolicExpressionEditor(
                  uiStyle: uiStyle,
                  expression: state.equation,
                  hintText: 'x^2 - 4 = 0',
                  onChanged: (value) => ref
                      .read(equationSolverProvider.notifier)
                      .setEquation(value),
                  onShowHelp: _showHelp,
                ),
                const SizedBox(height: 12),
                SymbolicVariableSelector(
                  uiStyle: uiStyle,
                  variables: state.variables,
                  selectedVariable: state.selectedVariable,
                  onSelected: (variable) => ref
                      .read(equationSolverProvider.notifier)
                      .selectVariable(variable),
                ),
                const SizedBox(height: 16),
                SymbolicPrimaryAction(
                  uiStyle: uiStyle,
                  label: 'Solve',
                  isBusy: state.isComputing,
                  isEnabled: state.canRun,
                  reason: state.unavailableReason(),
                  onPressed: _solve,
                ),
                if (_solveIsSlow) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Still working — this can take a moment for complex '
                    'equations',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 16),
                SymbolicSolveResultCard(uiStyle: uiStyle, state: state),
              ],
            ),
          );
        },
      ),
    );
  }
}
