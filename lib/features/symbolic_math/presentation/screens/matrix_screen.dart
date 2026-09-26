import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:calc_flut_rs/features/settings/presentation/providers/theme_provider.dart';
import 'package:calc_flut_rs/features/symbolic_math/presentation/providers/matrix_workspace.dart';
import 'package:calc_flut_rs/features/symbolic_math/presentation/widgets/matrix_input_grid.dart';
import 'package:calc_flut_rs/features/symbolic_math/presentation/widgets/matrix_result_panel.dart';
import 'package:calc_flut_rs/features/symbolic_math/presentation/widgets/symbolic_help_dialog.dart';
import 'package:calc_flut_rs/features/symbolic_math/presentation/widgets/symbolic_workspace_scaffold.dart';
import 'package:calc_flut_rs/shared/widgets/app_notice.dart';
import 'package:calc_flut_rs/shared/widgets/symbolic_primary_action.dart';

/// The Matrix workspace: determinant, rank, inverse and eigenvalues.
///
/// One Analyse action rather than a row of chips per quantity: a user who types
/// a matrix wants to see all of it at once, and six separate calls would be six
/// times the work for the same answer.
class MatrixScreen extends ConsumerStatefulWidget {
  const MatrixScreen({super.key});

  @override
  ConsumerState<MatrixScreen> createState() => _MatrixScreenState();
}

class _MatrixScreenState extends ConsumerState<MatrixScreen> {
  bool _isSlow = false;
  Timer? _indicatorTimer;
  Timer? _slowTimer;

  @override
  void dispose() {
    _indicatorTimer?.cancel();
    _slowTimer?.cancel();
    super.dispose();
  }

  /// Analyses the matrix, admitting slow work only once it is slow.
  Future<void> _analyse() async {
    _indicatorTimer?.cancel();
    _slowTimer?.cancel();
    setState(() => _isSlow = false);
    _indicatorTimer = Timer(SymbolicComputeTimings.indicatorDelay, () {
      if (mounted) setState(() => _isSlow = true);
    });
    _slowTimer = Timer(SymbolicComputeTimings.slowCallNotice, () {
      if (mounted) setState(() => _isSlow = true);
    });

    final succeeded = await ref.read(matrixProvider.notifier).analyse();

    _indicatorTimer?.cancel();
    _slowTimer?.cancel();
    if (!mounted) return;
    setState(() => _isSlow = false);

    // A partial answer is still an answer: a singular matrix has no inverse and
    // that is a fact about the matrix, not a failure to report.
    if (!succeeded && mounted) {
      final error = ref.read(matrixProvider).error;
      if (error != null) {
        showAppNotice(context, error.message, icon: Icons.error_outline);
      }
    }
  }

  void _showHelp() {
    showSymbolicHelpDialog(
      context: context,
      uiStyle: ref.read(uiStyleProvider),
      title: 'Matrices',
      description:
          'Type a grid of entries and analyse it. Rows and columns can be added '
          'or removed, because a matrix only has a determinant when it is square '
          '— the app says so rather than hiding the option.',
      notes: const [
        'Everything is exact: a determinant over thirty digits comes back as '
            'thirty digits, and 1/2 stays a fraction rather than 0.5.',
        'A singular matrix has no inverse. That is reported as absent with a '
            'reason, never as a zero.',
        'The eigenvectors are listed against their own eigenvalue, because the '
            'two do not line up when an eigenvalue repeats.',
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(matrixProvider);
    final uiStyle = ref.watch(uiStyleProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Matrices'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'About matrices',
            onPressed: _showHelp,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (!constraints.hasBoundedHeight || constraints.maxHeight <= 0) {
            return const SizedBox.shrink();
          }
          return SingleChildScrollView(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 8,
              bottom: 16 + MediaQuery.paddingOf(context).bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MatrixInputGrid(
                  uiStyle: uiStyle,
                  cells: state.cells,
                  onChanged: (cells) =>
                      ref.read(matrixProvider.notifier).setCells(cells),
                ),
                const SizedBox(height: 12),
                SymbolicPrimaryAction(
                  uiStyle: uiStyle,
                  label: 'Analyse',
                  isBusy: state.isComputing,
                  isEnabled: state.canAnalyse,
                  reason: state.unavailableReason(),
                  onPressed: _analyse,
                ),
                if (_isSlow) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Still working — larger matrices take longer',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 16),
                MatrixResultPanel(uiStyle: uiStyle, state: state),
              ],
            ),
          );
        },
      ),
    );
  }
}
