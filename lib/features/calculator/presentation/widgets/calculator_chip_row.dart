import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:calc_flut_rs/app/theme/ui_style.dart';
import 'package:calc_flut_rs/features/calculator/presentation/providers/calculator_provider.dart';
import 'package:calc_flut_rs/features/calculator/presentation/providers/calculator_state.dart';
import 'package:calc_flut_rs/shared/layouts/breakpoints.dart';
import 'package:calc_flut_rs/shared/widgets/app_chip.dart';

/// A row of interactive chips used to toggle scientific mode and open
/// secondary panels (Trig, Log, Mem).
class CalculatorChipRow extends StatelessWidget {
  /// Height of the chip strip itself, excluding this row's own padding.
  static const double rowHeight = 48.0;

  /// Vertical padding this row adds above and below the strip.
  static const double verticalPadding = 2.0;

  /// Total vertical space this row occupies, which is what the key rows below
  /// have to leave for.
  static const double totalHeight = rowHeight + verticalPadding * 2;

  final bool isSci;
  final ExpandedPanel expanded;
  final WidgetRef ref;
  final UiStyle uiStyle;

  const CalculatorChipRow({
    super.key,
    required this.isSci,
    required this.expanded,
    required this.ref,
    required this.uiStyle,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 3,
        vertical: CalculatorChipRow.verticalPadding,
      ),
      child: SizedBox(
        height: CalculatorChipRow.rowHeight,
        child: AnimatedSwitcher(
          duration: context.motion(const Duration(milliseconds: 250)),
          transitionBuilder: (child, animation) {
            return FadeTransition(opacity: animation, child: child);
          },
          child: Row(
            key: ValueKey(isSci),
            children: [
              _buildChip(
                context,
                label: 'Sci',
                bgColor: isSci
                    ? colorScheme.secondaryContainer
                    : colorScheme.surfaceContainerHigh,
                fgColor: isSci
                    ? colorScheme.onSecondaryContainer
                    : colorScheme.onSurfaceVariant,
                onTap: () => ref
                    .read(calculatorProvider.notifier)
                    .toggleScientificMode(),
                isExpanded: isSci,
              ),

              if (isSci) ...[
                const SizedBox(width: 6),
                Expanded(
                  child: _buildChip(
                    context,
                    label: 'Trig',
                    bgColor: colorScheme.tertiaryContainer,
                    fgColor: colorScheme.onTertiaryContainer,
                    onTap: () => ref
                        .read(calculatorProvider.notifier)
                        .togglePanel(ExpandedPanel.trig),
                    isExpanded: expanded == ExpandedPanel.trig,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _buildChip(
                    context,
                    label: 'Log',
                    bgColor: colorScheme.secondaryContainer,
                    fgColor: colorScheme.onSecondaryContainer,
                    onTap: () => ref
                        .read(calculatorProvider.notifier)
                        .togglePanel(ExpandedPanel.log),
                    isExpanded: expanded == ExpandedPanel.log,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _buildChip(
                    context,
                    label: 'Mem',
                    bgColor: colorScheme.primaryContainer,
                    fgColor: colorScheme.onPrimaryContainer,
                    onTap: () => ref
                        .read(calculatorProvider.notifier)
                        .togglePanel(ExpandedPanel.memory),
                    isExpanded: expanded == ExpandedPanel.memory,
                  ),
                ),
              ] else
                const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds one scientific-mode chip.
  ///
  /// Delegates to the shared [AppChip] so this row and the symbolic action row
  /// share a single chip implementation. The trailing caret stays owned here
  /// because only this row has something to expand.
  Widget _buildChip(
    BuildContext context, {
    required String label,
    required Color bgColor,
    required Color fgColor,
    required VoidCallback onTap,
    required bool isExpanded,
  }) {
    return AppChip(
      uiStyle: uiStyle,
      label: label,
      backgroundColor: bgColor,
      foregroundColor: fgColor,
      onTap: onTap,
      trailing: AnimatedRotation(
        duration: context.motion(const Duration(milliseconds: 200)),
        turns: isExpanded ? 0.5 : 0.0,
        child: Icon(Icons.expand_more, size: 18, color: fgColor),
      ),
    );
  }
}
