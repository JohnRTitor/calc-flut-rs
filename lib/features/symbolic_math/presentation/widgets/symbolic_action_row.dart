import 'package:flutter/material.dart';

import 'package:calc_flut_rs/app/theme/ui_style.dart';
import 'package:calc_flut_rs/features/symbolic_math/domain/symbolic_operation.dart';
import 'package:calc_flut_rs/features/symbolic_math/presentation/providers/symbolic_workspace_state.dart';
import 'package:calc_flut_rs/shared/widgets/app_chip.dart';

/// The row of operations that can be applied to the current expression.
///
/// Offers exactly the operations [SymbolicWorkspaceState.operations] lists, so
/// the same widget serves every tool in the section. Which operation is
/// in flight, and how long it has been, is owned by the workspace scaffold that
/// hosts this row.
class SymbolicActionRow extends StatelessWidget {
  final UiStyle uiStyle;

  /// The current workspace state, which decides what is enabled.
  final SymbolicWorkspaceState state;

  /// Invoked with the chosen operation.
  final ValueChanged<SymbolicOperation> onRun;

  /// The operation currently in flight, if any.
  final SymbolicOperation? computingOperation;

  const SymbolicActionRow({
    super.key,
    required this.uiStyle,
    required this.state,
    required this.onRun,
    this.computingOperation,
  });

  /// Fixed height, matching the scientific keypad's chip row.
  static const double height = 40.0;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: height,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 3),
        children: [
          for (final operation in state.operations) ...[
            _buildChip(context, colorScheme, operation),
            const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }

  Widget _buildChip(
    BuildContext context,
    ColorScheme colorScheme,
    SymbolicOperation operation,
  ) {
    final isEnabled = state.canRunOperation(operation);
    final isActive = state.operation == operation;
    final isComputing = computingOperation == operation;

    // The active operation keeps the emphasized treatment so the user can see
    // which operation produced what is on screen.
    final background = isActive
        ? colorScheme.primaryContainer
        : colorScheme.surfaceContainerHigh;
    final foreground = isActive
        ? colorScheme.onPrimaryContainer
        : colorScheme.onSurfaceVariant;

    return AppChip(
      uiStyle: uiStyle,
      label: operation.label,
      backgroundColor: background,
      foregroundColor: foreground,
      minimumHeight: AppChip.minimumTouchTarget,
      isEnabled: isEnabled,
      onTap: () => onRun(operation),
      semanticLabel: state.unavailableReason(operation) ?? operation.description,
      // Drawn over the label rather than beside it, so the row does not shift
      // when the indicator appears.
      overlay: isComputing
          ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: foreground,
              ),
            )
          : null,
    );
  }
}
