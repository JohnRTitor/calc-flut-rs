import 'package:flutter/material.dart';
import 'package:calc_flut_rs/app/theme/ui_style.dart';
import 'package:calc_flut_rs/shared/widgets/glass_utils.dart';

class ModularArithmeticResultCard extends StatelessWidget {
  final UiStyle uiStyle;
  final String? error;
  final String result;
  final String? details;
  final String? steps;
  final String preview;
  final bool showResult;

  const ModularArithmeticResultCard({
    super.key,
    required this.uiStyle,
    this.error,
    required this.result,
    this.details,
    this.steps,
    required this.preview,
    required this.showResult,
  });

  @override
  Widget build(BuildContext context) {
    if (error == null && !showResult && preview.isEmpty) {
      return const SizedBox.shrink();
    }

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
            'Result:',
            style: theme.textTheme.labelMedium?.copyWith(
              color: uiStyle == UiStyle.liquidGlass ? Colors.white70 : theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          if (error != null)
            Text(
              error!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
              textAlign: TextAlign.center,
            )
          else if (showResult)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                Text(
                  result,
                  style: theme.textTheme.displaySmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.left,
                ),
                if (details != null && details!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    details!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.left,
                  ),
                ],
                if (steps != null && steps!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      steps!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.left,
                    ),
                  ),
                ],
              ],
            )
          else if (preview.isNotEmpty)
            Text(
              preview,
              textAlign: TextAlign.left,
              style: theme.textTheme.headlineMedium?.copyWith(
                color: theme.colorScheme.primary.withValues(alpha: 0.7),
              ),
            ),
        ],
      ),
    );
  }
}
