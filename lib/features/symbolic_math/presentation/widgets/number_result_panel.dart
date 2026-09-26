import 'package:flutter/material.dart';

import 'package:calc_flut_rs/app/theme/ui_style.dart';
import 'package:calc_flut_rs/features/symbolic_math/presentation/providers/number_theory_workspace.dart';
import 'package:calc_flut_rs/generated/rust/bridge/symbolic.dart'
    as rust_symbolic;
import 'package:calc_flut_rs/shared/widgets/glass_utils.dart';

/// The result surface for the Number Theory workspace.
///
/// Every fact about the number at once, as labelled rows in the same shape the
/// modular analysis grid uses. Quantities that are undefined — the totient of
/// 0, a divisor list for a number with infinitely many — are left out with the
/// reason in the qualifier, because a 0 there would be a real totient of 0
/// rather than "there isn't one".
class NumberResultPanel extends StatelessWidget {
  final UiStyle uiStyle;
  final NumberTheoryState state;

  const NumberResultPanel({
    super.key,
    required this.uiStyle,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    final analysis = state.analysis;
    final error = state.error;
    if (analysis == null && error == null && !state.hasPairResult) {
      return const SizedBox.shrink();
    }

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
            'Number',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: uiStyle == UiStyle.liquidGlass
                  ? Colors.white70
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          if (error != null) ...[
            Text(
              error.message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
            if (error.suggestion != null && error.suggestion!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                error.suggestion!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ] else ...[
            if (analysis != null) ..._facts(context, analysis),
            if (state.hasPairResult) ..._pairRows(context),
          ],
        ],
      ),
    );
  }

  List<Widget> _facts(
    BuildContext context,
    rust_symbolic.NumberAnalysisResponse analysis,
  ) {
    final theme = Theme.of(context);
    final rows = <Widget>[];

    final properties = <String>[
      if (analysis.isPrime) 'prime',
      if (analysis.isSquare) 'a perfect square',
      if (analysis.isPerfect) 'a perfect number',
      if (analysis.isCarmichael) 'a Carmichael number',
    ];
    // Said plainly, because "no properties" is itself the interesting answer
    // for most composite numbers.
    rows.add(
      _row(
        context,
        'Properties',
        properties.isEmpty ? 'none of the special ones' : properties.join(', '),
      ),
    );

    rows.add(_row(context, 'Factorisation', _factorisation(analysis.factors)));
    rows.add(_row(context, 'Divisor count', '${analysis.divisorCount}'));
    rows.add(_row(context, 'Divisor sum', _orNull(analysis.divisorSum)));
    rows.add(_row(context, "Euler's totient", _orNull(analysis.totient)));
    rows.add(_row(context, 'Next prime', _orNull(analysis.nextPrime)));
    rows.add(_row(context, 'Previous prime', _orNull(analysis.previousPrime)));

    if (analysis.divisors.isNotEmpty) {
      rows.add(
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 10),
          child: Text(
            'Divisors: ${analysis.divisors.join(',  ')}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    final details = analysis.details;
    if (details != null && details.isNotEmpty) {
      rows.add(
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            details,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return rows;
  }

  List<Widget> _pairRows(BuildContext context) {
    final rows = <Widget>[];
    if (state.gcd != null) {
      rows.add(
        _row(
          context,
          'GCD of the two',
          'gcd(${state.number}, ${state.other}) = ${state.gcd}',
        ),
      );
    }
    if (state.lcm != null) {
      rows.add(
        _row(
          context,
          'LCM of the two',
          'lcm(${state.number}, ${state.other}) = ${state.lcm}',
        ),
      );
    }
    if (state.coprime != null) {
      rows.add(
        _row(
          context,
          'Coprime',
          state.coprime!
              ? 'Yes — no common factor other than 1'
              : 'No — they share a factor',
        ),
      );
    }
    return rows;
  }

  /// `null` rather than an empty string, so a genuinely absent value shows no
  /// row rather than an empty one.
  static String? _orNull(String value) => value.isEmpty ? null : value;

  static String? _factorisation(List<rust_symbolic.PrimePower> factors) {
    if (factors.isEmpty) return null;
    return factors
        .map(
          (factor) => factor.power == 1
              ? factor.prime
              : '${factor.prime}^${factor.power}',
        )
        .join(' * ');
  }

  Widget _row(BuildContext context, String label, String? value) {
    if (value == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 116,
            child: Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
