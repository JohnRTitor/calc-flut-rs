import 'package:flutter/material.dart';

import 'package:calc_flut_rs/app/theme/ui_style.dart';
import 'package:calc_flut_rs/shared/widgets/glass_utils.dart';

/// The single primary action of a tool that has exactly one thing to do.
///
/// A full-width button rather than a one-chip action row: a row would be all
/// chip and no substance. Shared by the Equation Solver, Matrices and Number
/// Theory, which each have one action rather than a set to choose from.
///
/// When disabled it still says why, with the reason as the label, so the
/// control is never silently inert.
class SymbolicPrimaryAction extends StatelessWidget {
  final UiStyle uiStyle;

  /// The label, or the reason it is unavailable.
  final String label;

  /// Whether a call is in flight, which shows a spinner in place of nothing.
  final bool isBusy;

  /// Whether the action can run.
  final bool isEnabled;

  /// Why it cannot, or `null` when it can.
  final String? reason;

  final VoidCallback onPressed;

  const SymbolicPrimaryAction({
    super.key,
    required this.uiStyle,
    required this.label,
    required this.isBusy,
    required this.isEnabled,
    required this.reason,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = reason ?? label;

    final child = Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isBusy) ...[
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: theme.colorScheme.onPrimary,
              ),
            ),
            const SizedBox(width: 12),
          ],
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    return Tooltip(
      message: reason ?? label,
      child: SizedBox(
        height: 56,
        child: SharedSurface(
          uiStyle: uiStyle,
          isInteractive: true,
          isSelected: true,
          glassRole: GlassSurfaceRole.primary,
          borderRadius: BorderRadius.circular(16),
          onTap: isEnabled ? onPressed : null,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: child,
        ),
      ),
    );
  }
}
