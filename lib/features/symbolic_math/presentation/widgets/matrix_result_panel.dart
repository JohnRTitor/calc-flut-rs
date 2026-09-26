import 'package:flutter/material.dart';

import 'package:calc_flut_rs/app/theme/ui_style.dart';
import 'package:calc_flut_rs/features/symbolic_math/presentation/providers/matrix_workspace.dart';
import 'package:calc_flut_rs/generated/rust/bridge/symbolic.dart'
    as rust_symbolic;
import 'package:calc_flut_rs/shared/widgets/glass_utils.dart';

/// The result surface for the Matrix workspace.
///
/// A labelled value per row — the same "small list of labelled values" shape the
/// modular analysis grid uses, rather than a new layout.
///
/// Quantities that do not apply are left out rather than shown as blank or zero:
/// a matrix with no inverse does not have an inverse of 0, and drawing a row
/// with nothing in it invites exactly that reading. The reason goes in the
/// qualifier line instead.
class MatrixResultPanel extends StatelessWidget {
  final UiStyle uiStyle;
  final MatrixState state;

  const MatrixResultPanel({
    super.key,
    required this.uiStyle,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    final analysis = state.analysis;
    final error = state.error;
    if (analysis == null && error == null) return const SizedBox.shrink();

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
            'Matrix',
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
          ] else
            ..._rows(context, analysis!),
        ],
      ),
    );
  }

  List<Widget> _rows(
    BuildContext context,
    rust_symbolic.MatrixAnalysisResponse analysis,
  ) {
    final rows = <Widget>[];

    // Rank is always defined, so it is always shown.
    rows.add(_row(context, 'Rank', '${analysis.rank}'));
    rows.add(_row(context, 'Determinant', analysis.determinant));
    rows.add(_row(context, 'Trace', analysis.trace));
    rows.add(
      _row(
        context,
        'Reduced form',
        _brackets(analysis.reduced, analysis.columns),
      ),
    );
    rows.add(
      _row(context, 'Inverse', _brackets(analysis.inverse, analysis.columns)),
    );

    final eigenvalues = analysis.eigenvalues;
    if (eigenvalues != null) {
      rows.add(_row(context, 'Eigenvalues', eigenvalues.join(',   ')));
    }

    // Each vector names the eigenvalue it belongs to, because the eigenvectors
    // and the eigenvalues do not line up positionally and pairing them by
    // position would report the wrong vector against the wrong value.
    final vectors = analysis.eigenvectors;
    if (vectors != null) {
      for (final entry in vectors) {
        rows.add(
          _row(
            context,
            'Eigenvector for ${entry.eigenvalue}',
            entry.vector.join(',   '),
          ),
        );
      }
    }

    final details = analysis.details;
    if (details != null && details.isNotEmpty) {
      rows.add(
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            details,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return rows;
  }

  /// Renders a flat, row-major matrix as bracketed rows, or `null` if absent.
  ///
  /// The cells arrive as a single list because the bridge cannot encode a
  /// nested vector, so the width travels alongside to recover the rows.
  static String? _brackets(List<String>? cells, int columns) {
    if (cells == null || cells.isEmpty) return null;
    if (columns <= 0) return null;
    final rows = <String>[];
    for (var start = 0; start + columns <= cells.length; start += columns) {
      rows.add('[${cells.sublist(start, start + columns).join('  ')}]');
    }
    return rows.join('\n');
  }

  Widget _row(BuildContext context, String label, String? value) {
    if (value == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    // A multi-line value is a matrix, which reads better aligned than a
    // proportional font can manage.
    final isMatrix = value.contains('\n');

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
                fontFamily: isMatrix ? 'monospace' : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
