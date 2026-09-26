import 'package:flutter/material.dart';

import 'package:calc_flut_rs/app/theme/app_theme_extension.dart';
import 'package:calc_flut_rs/app/theme/ui_style.dart';
import 'package:calc_flut_rs/features/symbolic_math/presentation/providers/symbolic_workspace_state.dart';
import 'package:calc_flut_rs/shared/widgets/app_chip.dart';
import 'package:calc_flut_rs/shared/widgets/glass_utils.dart';
import 'package:calc_flut_rs/shared/widgets/math_expression_text.dart';

/// The result surface for the Algebra workspace.
///
/// Follows the app's three-tier disclosure convention, the same shape used by
/// the calculator's display panel and the modular arithmetic result card:
///
/// 1. the primary value, large and high contrast;
/// 2. a short qualifier, in the quieter `onSurfaceVariant` tone;
/// 3. step-by-step working, in a monospace block, only when Educational Mode
///    produced any.
///
/// A failure is a fourth, visually distinct state rather than a variation of
/// the value: red body text, never styled as if it were an answer.
class SymbolicResultCard extends StatelessWidget {
  final UiStyle uiStyle;
  final SymbolicWorkspaceState state;

  /// Copies [SymbolicWorkspaceState.displayValue] to the clipboard.
  final VoidCallback? onCopy;

  /// Switches the primary value to another known form.
  final ValueChanged<int>? onShowForm;

  /// Explains a practical limit, shown beside a `too_large` failure.
  final VoidCallback? onExplainLimit;

  const SymbolicResultCard({
    super.key,
    required this.uiStyle,
    required this.state,
    this.onCopy,
    this.onShowForm,
    this.onExplainLimit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final themeExt = theme.extension<AppThemeExtension>()!;

    final error = state.error;
    // Nothing to say yet: no result, no failure. Rendering an empty card would
    // just be chrome.
    if (!state.hasResult && error == null) return const SizedBox.shrink();

    return SharedSurface(
      uiStyle: uiStyle,
      glassRole: GlassSurfaceRole.card,
      frosted: true,
      borderRadius: BorderRadius.circular(24),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(context, colorScheme, themeExt),
          const SizedBox(height: 16),
          if (error != null)
            _buildError(context, colorScheme, error)
          else
            ..._buildValue(context, colorScheme, themeExt),
        ],
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    ColorScheme colorScheme,
    AppThemeExtension themeExt,
  ) {
    return Row(
      children: [
        Expanded(
          child: Text(
            state.operation == null ? 'Result' : '${state.operation!.label} result',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: uiStyle == UiStyle.liquidGlass
                  ? Colors.white70
                  : colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        if (state.hasResult && onCopy != null)
          SizedBox(
            width: AppChip.minimumTouchTarget,
            height: AppChip.minimumTouchTarget,
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.copy_all_outlined, size: 20),
              tooltip: 'Copy result',
              onPressed: onCopy,
              color: themeExt.resultText.withValues(alpha: 0.8),
            ),
          ),
      ],
    );
  }

  List<Widget> _buildValue(
    BuildContext context,
    ColorScheme colorScheme,
    AppThemeExtension themeExt,
  ) {
    return [
      // Dim the previous answer while a new one is being computed rather than
      // clearing the card: the work is still legitimately under way.
      Opacity(
        opacity: state.isComputing ? 0.4 : 1.0,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          reverse: true,
          child: MathExpressionText(
            expression: state.displayValue,
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              color: themeExt.resultText,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
      if (state.details != null && state.details!.isNotEmpty) ...[
        const SizedBox(height: 8),
        Text(
          state.details!,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
      if (state.hasMultipleForms) ...[
        const SizedBox(height: 16),
        _buildFormChips(context, themeExt),
      ],
      if (state.steps != null && state.steps!.isNotEmpty) ...[
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            state.steps!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontFamily: 'monospace',
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    ];
  }

  /// Chips for the other known forms of this expression.
  ///
  /// Styled as informational result chips rather than action chips: these switch
  /// between answers, they do not run anything.
  Widget _buildFormChips(BuildContext context, AppThemeExtension themeExt) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var index = 0; index < state.forms.length; index++)
          _FormChip(
            uiStyle: uiStyle,
            form: state.forms[index],
            isActive: index == state.activeFormIndex,
            onTap: onShowForm == null ? null : () => onShowForm!(index),
          ),
      ],
    );
  }

  Widget _buildError(
    BuildContext context,
    ColorScheme colorScheme,
    SymbolicFailure error,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          error.message,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: colorScheme.error,
          ),
        ),
        if (error.suggestion != null && error.suggestion!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            error.suggestion!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        if (error.isLimitation && onExplainLimit != null) ...[
          const SizedBox(height: 8),
          _LearnMoreLink(onTap: onExplainLimit!),
        ],
      ],
    );
  }
}

/// A single alternate-form chip.
class _FormChip extends StatelessWidget {
  final UiStyle uiStyle;
  final SymbolicForm form;
  final bool isActive;
  final VoidCallback? onTap;

  const _FormChip({
    required this.uiStyle,
    required this.form,
    required this.isActive,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeExt = theme.extension<AppThemeExtension>()!;
    final colorScheme = theme.colorScheme;

    final background = isActive
        ? colorScheme.primaryContainer
        : themeExt.chipBackground;
    final foreground = isActive
        ? colorScheme.onPrimaryContainer
        : themeExt.chipText;

    return Tooltip(
      message: 'Show the ${form.label.toLowerCase()} form',
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 40),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    form.label,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: foreground,
                      fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 6),
                  // The expression itself is shown small, so a chip reads as a
                  // peek at the answer rather than just a label.
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 120),
                    child: MathExpressionText(
                      expression: form.expression,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: foreground.withValues(alpha: 0.75),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The "Learn More" affordance used by the app's limitation banners.
class _LearnMoreLink extends StatelessWidget {
  final VoidCallback onTap;

  const _LearnMoreLink({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.help_outline, size: 18),
        label: const Text('Learn More'),
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          minimumSize: const Size(0, 40),
        ),
      ),
    );
  }
}
