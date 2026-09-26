import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:calc_flut_rs/features/settings/presentation/providers/theme_provider.dart';
import 'package:calc_flut_rs/features/symbolic_math/domain/symbolic_operation.dart';
import 'package:calc_flut_rs/features/symbolic_math/presentation/providers/symbolic_workspace.dart';
import 'package:calc_flut_rs/features/symbolic_math/presentation/widgets/symbolic_bound_inputs.dart';
import 'package:calc_flut_rs/shared/widgets/pill_switcher.dart';
import '../widgets/symbolic_workspace_scaffold.dart';

/// The Calculus workspace: differentiate, and integrate either way.
///
/// Two-way segmented choice rather than two separate chips for `Integrate`,
/// because the two are the same verb with different inputs and different
/// answers. A chip per variant would put two identically-labelled buttons side
/// by side and make the user work out which was which.
///
/// Sibling of the Algebra workspace rather than a mode inside it: calculus is a
/// distinct operation family, and the Symbolic Math section already reserves a
/// card for it. Layout, timing and the result surface all come from
/// [SymbolicWorkspaceScaffold].
class CalculusScreen extends ConsumerStatefulWidget {
  const CalculusScreen({super.key});

  @override
  ConsumerState<CalculusScreen> createState() => _CalculusScreenState();
}

class _CalculusScreenState extends ConsumerState<CalculusScreen> {
  IntegrationMode _mode = IntegrationMode.indefinite;

  /// Switches the flavour of integration, keeping the expression and bounds.
  void _setMode(IntegrationMode mode) {
    setState(() => _mode = mode);
    ref
        .read(calculusProvider.notifier)
        .setOperations(IntegrationMode.operationsFor(mode));
  }

  @override
  Widget build(BuildContext context) {
    final uiStyle = ref.watch(uiStyleProvider);
    final state = ref.watch(calculusProvider);
    final notifier = ref.read(calculusProvider.notifier);
    final operations = IntegrationMode.operationsFor(_mode);

    return SymbolicWorkspaceScaffold(
      title: 'Calculus',
      hintText: 'x^2*sin(x)',
      provider: calculusProvider,
      operations: operations,
      extraControls: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              PillSwitcher(
                uiStyle: uiStyle,
                label1: IntegrationMode.indefinite.label,
                label2: IntegrationMode.definite.label,
                tooltip1: 'Find an antiderivative, up to an arbitrary constant',
                tooltip2: 'Evaluate the integral between two bounds',
                isFirstSelected: _mode == IntegrationMode.indefinite,
                onChanged: (isIndefinite) => _setMode(
                  isIndefinite
                      ? IntegrationMode.indefinite
                      : IntegrationMode.definite,
                ),
              ),
            ],
          ),
          // Bounds exist only in definite mode. Showing them for an indefinite
          // integral would imply they did something to the answer.
          if (_mode == IntegrationMode.definite) ...[
            const SizedBox(height: 12),
            SymbolicBoundInputs(
              uiStyle: uiStyle,
              lowerBound: state.lowerBound,
              upperBound: state.upperBound,
              onLowerChanged: (text) => notifier.setBound(isLower: true, text: text),
              onUpperChanged: (text) => notifier.setBound(isLower: false, text: text),
            ),
          ],
        ],
      ),
    );
  }
}
