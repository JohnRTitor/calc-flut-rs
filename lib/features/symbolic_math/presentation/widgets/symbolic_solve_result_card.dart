import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:calc_flut_rs/app/theme/app_theme_extension.dart';
import 'package:calc_flut_rs/app/theme/ui_style.dart';
import 'package:calc_flut_rs/features/symbolic_math/presentation/providers/equation_solver_state.dart';
import 'package:calc_flut_rs/generated/rust/bridge/symbolic.dart' as rust_symbolic;
import 'package:calc_flut_rs/shared/widgets/app_chip.dart';
import 'package:calc_flut_rs/shared/widgets/glass_utils.dart';
import 'package:calc_flut_rs/shared/widgets/math_expression_text.dart';

/// The result surface for the Equation Solver.
///
/// Covers all four mathematical outcomes, and the central point is that three of
/// them are answers rather than failures:
///
/// * one solution — shown like any other single value, with no special case;
/// * several — a short list, each row individually copyable;
/// * every value works — said in plain words in the qualifier line;
/// * nothing works — also said in plain words, and deliberately *not* in the
///   error colour, because the user did nothing wrong and the maths is simply
///   telling them there is no answer.
class SymbolicSolveResultCard extends StatelessWidget {
  final UiStyle uiStyle;
  final EquationSolverState state;

  const SymbolicSolveResultCard({super.key, required this.uiStyle, required this.state});

  @override
  Widget build(BuildContext context) {
    final error = state.error;
    if (!state.hasResult && error == null) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return SharedSurface(
      uiStyle: uiStyle,
      glassRole: GlassSurfaceRole.card,
      frosted: true,
      borderRadius: BorderRadius.circular(24),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Result',
            style: theme.textTheme.labelMedium?.copyWith(
              color: uiStyle == UiStyle.liquidGlass
                  ? Colors.white70
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          if (error != null) ...[
            Text(
              error.message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
            if (error.suggestion != null && error.suggestion!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  error.suggestion!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ] else
            ..._buildOutcome(context, theme),
        ],
      ),
    );
  }

  List<Widget> _buildOutcome(BuildContext context, ThemeData theme) {
    // A finite set of one is just a value, so it takes the ordinary path.
    if (state.solutionKind == rust_symbolic.SolutionKind.unique) {
      return _singleValue(context, theme);
    }
    if (state.hasMultipleSolutions) {
      return _solutionList(context, theme);
    }
    // Infinite and none are both "a sentence, not a list", and both are correct
    // answers rather than failures.
    return _qualifier(context, theme);
  }

  List<Widget> _singleValue(BuildContext context, ThemeData theme) {
    final themeExt = theme.extension<AppThemeExtension>()!;
    return [
      Opacity(
        opacity: state.isComputing ? 0.4 : 1.0,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          reverse: true,
          child: MathExpressionText(
            expression: state.solutions.first,
            style: theme.textTheme.displaySmall?.copyWith(
              color: themeExt.resultText,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
      if (state.details != null && state.details!.isNotEmpty)
        _qualifierLine(context, theme, state.details!),
      if (state.steps != null && state.steps!.isNotEmpty)
        _stepsBlock(context, theme, state.steps!),
    ];
  }

  /// The solutions as a short list of paired rows, each copyable on its own.
  ///
  /// Copying one root is the common case, so it must not require copying the
  /// whole set.
  List<Widget> _solutionList(BuildContext context, ThemeData theme) {
    final themeExt = theme.extension<AppThemeExtension>()!;
    final variable = state.selectedVariable ?? 'x';

    return [
      for (final solution in state.solutions)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  reverse: true,
                  child: MathExpressionText(
                    expression: '$variable = $solution',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: themeExt.resultText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: AppChip.minimumTouchTarget,
                height: AppChip.minimumTouchTarget,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.copy, size: 18),
                  tooltip: 'Copy $solution',
                  color: themeExt.resultText.withValues(alpha: 0.7),
                  onPressed: () =>
                      Clipboard.setData(ClipboardData(text: '$variable = $solution')),
                ),
              ),
            ],
          ),
        ),
      if (state.details != null && state.details!.isNotEmpty)
        _qualifierLine(context, theme, state.details!),
      if (state.steps != null && state.steps!.isNotEmpty)
        _stepsBlock(context, theme, state.steps!),
    ];
  }

  /// "Every value works" and "nothing works" both land here.
  List<Widget> _qualifier(BuildContext context, ThemeData theme) {
    final message = switch (state.solutionKind) {
      final kind when kind == rust_symbolic.SolutionKind.infinite =>
        'Every value of the variable satisfies this equation',
      _ => 'No solution',
    };
    return [
      Text(
        message,
        style: theme.textTheme.headlineSmall?.copyWith(
          color: theme.colorScheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
      ),
      if (state.details != null && state.details!.isNotEmpty)
        _qualifierLine(context, theme, state.details!),
      if (state.steps != null && state.steps!.isNotEmpty)
        _stepsBlock(context, theme, state.steps!),
    ];
  }

  Widget _qualifierLine(BuildContext context, ThemeData theme, String details) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        details,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _stepsBlock(BuildContext context, ThemeData theme, String steps) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        steps,
        style: theme.textTheme.bodySmall?.copyWith(
          fontFamily: 'monospace',
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
