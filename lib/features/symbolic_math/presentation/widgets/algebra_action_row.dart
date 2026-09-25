import 'package:flutter/material.dart';

import 'package:calc_flut_rs/app/theme/ui_style.dart';
import 'package:calc_flut_rs/features/symbolic_math/presentation/providers/algebra_state.dart';
import 'package:calc_flut_rs/shared/widgets/app_chip.dart';

/// Thresholds that govern when the workspace admits it is working.
///
/// Named rather than inlined so the feel can be tuned after release without
/// hunting through build methods.
class SymbolicComputeTimings {
  const SymbolicComputeTimings._();

  /// How long a call may run before a progress indicator appears.
  ///
  /// Almost every algebraic operation resolves in well under this, and a
  /// spinner that flashes for 30ms reads as a glitch rather than as feedback.
  /// Nothing is shown until a call is genuinely slow.
  static const Duration indicatorDelay = Duration(milliseconds: 150);

  /// How long a call may run before a reassurance line appears.
  ///
  /// Symbolic work has no hard upper bound, so past this point the user is told
  /// it is still running rather than being left guessing whether the tap
  /// registered.
  static const Duration slowCallNotice = Duration(seconds: 8);
}

/// The row of operations that can be applied to the current expression.
///
/// Appears only once there is an expression to act on, so nothing advanced is
/// on screen until it is relevant. Scrolls horizontally rather than compressing
/// when more operations are available than fit.
class AlgebraActionRow extends StatelessWidget {
  final UiStyle uiStyle;

  /// The current workspace state, which decides what is enabled.
  final AlgebraState state;

  /// Invoked with the chosen operation.
  final ValueChanged<AlgebraOperation> onRun;

  /// The operation currently in flight, if any.
  final AlgebraOperation? computingOperation;

  const AlgebraActionRow({
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
          for (final operation in AlgebraOperation.values) ...[
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
    AlgebraOperation operation,
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
