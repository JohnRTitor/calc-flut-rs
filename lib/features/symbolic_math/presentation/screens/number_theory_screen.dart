import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:calc_flut_rs/app/theme/ui_style.dart';
import 'package:calc_flut_rs/features/settings/presentation/providers/theme_provider.dart';
import 'package:calc_flut_rs/features/symbolic_math/presentation/providers/number_theory_workspace.dart';
import 'package:calc_flut_rs/features/symbolic_math/presentation/widgets/number_result_panel.dart';
import 'package:calc_flut_rs/features/symbolic_math/presentation/widgets/symbolic_help_dialog.dart';
import 'package:calc_flut_rs/features/symbolic_math/presentation/widgets/symbolic_workspace_scaffold.dart';
import 'package:calc_flut_rs/shared/widgets/app_notice.dart';
import 'package:calc_flut_rs/shared/widgets/glass_utils.dart';
import 'package:calc_flut_rs/shared/widgets/symbolic_primary_action.dart';

/// The Number Theory workspace: one integer, and every fact about it.
///
/// All the single-number facts come from one call, so they arrive together
/// rather than one per tap. The two-number operations are separated out
/// because they need a second input, and mixing a one-number result with a
/// two-number one in the same list would blur which was which.
class NumberTheoryScreen extends ConsumerStatefulWidget {
  const NumberTheoryScreen({super.key});

  @override
  ConsumerState<NumberTheoryScreen> createState() => _NumberTheoryScreenState();
}

class _NumberTheoryScreenState extends ConsumerState<NumberTheoryScreen> {
  late final TextEditingController _numberController;
  late final TextEditingController _otherController;

  bool _isSlow = false;
  Timer? _indicatorTimer;
  Timer? _slowTimer;

  @override
  void initState() {
    super.initState();
    _numberController = TextEditingController(
      text: ref.read(numberTheoryProvider).number,
    );
    _otherController = TextEditingController(
      text: ref.read(numberTheoryProvider).other,
    );
  }

  @override
  void dispose() {
    _indicatorTimer?.cancel();
    _slowTimer?.cancel();
    _numberController.dispose();
    _otherController.dispose();
    super.dispose();
  }

  /// Runs [work] with the shared slow-call feedback, reporting a failure once.
  Future<void> _run(Future<bool> Function() work) async {
    _indicatorTimer?.cancel();
    _slowTimer?.cancel();
    setState(() => _isSlow = false);
    _indicatorTimer = Timer(SymbolicComputeTimings.indicatorDelay, () {
      if (mounted) setState(() => _isSlow = true);
    });
    _slowTimer = Timer(SymbolicComputeTimings.slowCallNotice, () {
      if (mounted) setState(() => _isSlow = true);
    });

    final succeeded = await work();

    _indicatorTimer?.cancel();
    _slowTimer?.cancel();
    if (!mounted) return;
    setState(() => _isSlow = false);

    if (!succeeded && mounted) {
      final error = ref.read(numberTheoryProvider).error;
      if (error != null) {
        showAppNotice(context, error.message, icon: Icons.error_outline);
      }
    }
  }

  Future<void> _analyse() =>
      _run(() => ref.read(numberTheoryProvider.notifier).analyse());

  Future<void> _gcd() => _run(() async {
    await ref.read(numberTheoryProvider.notifier).compareGcd();
    return true;
  });

  Future<void> _lcm() => _run(() async {
    await ref.read(numberTheoryProvider.notifier).compareLcm();
    return true;
  });

  Future<void> _coprime() => _run(() async {
    await ref.read(numberTheoryProvider.notifier).compareCoprime();
    return true;
  });

  void _showHelp() {
    showSymbolicHelpDialog(
      context: context,
      uiStyle: ref.read(uiStyleProvider),
      title: 'Number Theory',
      description:
          'Enter a whole number and analyse it. Every result is exact, so a '
          'twenty-digit factorisation comes back in full.',
      notes: const [
        'A negative number keeps its sign: −12 factors as −1 × 2² × 3.',
        'Some quantities have no value for 0 or 1 — the totient of 0 does not '
            'exist, and every positive integer divides 0. Those are reported '
            'as absent with a reason, never as 0.',
        'The size limit is on the digits you type, not on how long the work '
            'takes: a number of the same length can be quick or slow depending '
            'on its factors.',
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(numberTheoryProvider);
    final uiStyle = ref.watch(uiStyleProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Number Theory'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'About number theory',
            onPressed: _showHelp,
            color: theme.colorScheme.onSurfaceVariant,
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
                _NumberField(
                  uiStyle: uiStyle,
                  label: 'Number',
                  controller: _numberController,
                  onChanged: (value) =>
                      ref.read(numberTheoryProvider.notifier).setNumber(value),
                ),
                const SizedBox(height: 12),
                SymbolicPrimaryAction(
                  uiStyle: uiStyle,
                  label: 'Analyse',
                  isBusy: state.isComputing,
                  isEnabled: state.canAnalyse,
                  reason: state.canAnalyse ? null : 'Enter a whole number',
                  onPressed: _analyse,
                ),
                if (_isSlow) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Still working — factorisation can take a moment',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Compare two numbers',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _NumberField(
                        uiStyle: uiStyle,
                        label: 'With',
                        controller: _otherController,
                        onChanged: (value) => ref
                            .read(numberTheoryProvider.notifier)
                            .setOther(value),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    _PairButton(
                      label: 'GCD',
                      enabled: state.canCompare,
                      onPressed: _gcd,
                    ),
                    _PairButton(
                      label: 'LCM',
                      enabled: state.canCompare,
                      onPressed: _lcm,
                    ),
                    _PairButton(
                      label: 'Coprime?',
                      enabled: state.canCompare,
                      onPressed: _coprime,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                NumberResultPanel(uiStyle: uiStyle, state: state),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// A whole-number field.
class _NumberField extends StatelessWidget {
  final UiStyle uiStyle;
  final String label;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _NumberField({
    required this.uiStyle,
    required this.label,
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SharedSurface(
      uiStyle: uiStyle,
      glassRole: GlassSurfaceRole.card,
      frosted: true,
      borderRadius: BorderRadius.circular(20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              style: theme.textTheme.titleLarge,
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: '360',
                hintStyle: theme.textTheme.titleLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                ),
              ),
              keyboardType: const TextInputType.numberWithOptions(signed: true),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

/// One of the two-number operations.
class _PairButton extends StatelessWidget {
  final String label;
  final bool enabled;
  final VoidCallback onPressed;

  const _PairButton({
    required this.label,
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextButton(
      onPressed: enabled ? onPressed : null,
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        foregroundColor: theme.colorScheme.onSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      child: Text(label),
    );
  }
}
