import 'package:flutter/material.dart';
import 'package:calc_flut_rs/app/theme/ui_style.dart';
import 'package:calc_flut_rs/shared/widgets/glass_utils.dart';

class ModularArithmeticHelpBottomSheet extends StatelessWidget {
  final UiStyle uiStyle;

  const ModularArithmeticHelpBottomSheet({super.key, required this.uiStyle});

  static Future<void> show(BuildContext context, {required UiStyle uiStyle}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ModularArithmeticHelpBottomSheet(uiStyle: uiStyle),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;

    return Container(
      height: size.height * 0.85,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SharedSurface(
        uiStyle: uiStyle,
        glassRole: GlassSurfaceRole.panel,
        frosted: true,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: Column(
          children: [
            // Drag handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 16),
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.4,
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Modular Arithmetic Guide',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 24),

                    _buildSectionTitle('What is Z/nZ?', theme),
                    _buildText(
                      'Z/nZ represents the ring of integers modulo n. In this system, numbers wrap around after reaching the value n. '
                      'For example, in Z/12Z (like a clock), 10 + 4 = 14, which wraps around to 2.',
                      theme,
                    ),

                    _buildSectionTitle('What is GF(p)?', theme),
                    _buildText(
                      'GF(p) represents a Galois Field (or finite field) of prime order p. Every non-zero element has a multiplicative inverse, '
                      'meaning you can add, subtract, multiply, and divide without leaving the field.',
                      theme,
                    ),

                    _buildSectionTitle('Supported Operations', theme),
                    _buildOperationList(theme),

                    _buildSectionTitle('Syntax Examples', theme),
                    _buildExampleList(theme),

                    const SizedBox(height: 48), // Bottom padding
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(top: 24.0, bottom: 8.0),
      child: Text(
        title,
        style: theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildText(String text, ThemeData theme) {
    return Text(
      text,
      style: theme.textTheme.bodyLarge?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        height: 1.5,
      ),
    );
  }

  Widget _buildOperationList(ThemeData theme) {
    final operations = [
      ('+', 'Addition modulo n'),
      ('-', 'Subtraction modulo n'),
      ('*', 'Multiplication modulo n'),
      ('/', 'Division modulo n (requires inverse)'),
      ('^', 'Exponentiation modulo n'),
      ('inverse(x)', 'Multiplicative inverse of x modulo n'),
      ('powmod(b, e)', 'Efficient b^e modulo n'),
      ('gcd(a, b)', 'Greatest common divisor'),
      ('totient(n)', 'Euler\'s totient function'),
    ];

    return Column(
      children: operations
          .map(
            (op) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 100,
                    child: Text(
                      op.$1,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(op.$2, style: theme.textTheme.bodyMedium),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildExampleList(ThemeData theme) {
    final examples = [
      '5 + 8',
      '3 * 7 - 2',
      'powmod(2, 100)',
      'inverse(3)',
      'gcd(14, 21)',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: examples
          .map(
            (ex) => Container(
              margin: const EdgeInsets.symmetric(vertical: 4.0),
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.5,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                ex,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}
