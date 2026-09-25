import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:calc_flut_rs/app/theme/app_theme_extension.dart';
import 'package:calc_flut_rs/app/theme/ui_style.dart';
import 'package:calc_flut_rs/features/settings/presentation/providers/theme_provider.dart';
import 'package:calc_flut_rs/features/symbolic_math/presentation/providers/algebra_provider.dart';
import 'package:calc_flut_rs/features/symbolic_math/presentation/providers/algebra_state.dart';
import 'package:calc_flut_rs/features/symbolic_math/presentation/widgets/algebra_action_row.dart';
import 'package:calc_flut_rs/features/symbolic_math/presentation/widgets/algebra_result_card.dart';
import 'package:calc_flut_rs/generated/rust/bridge/symbolic.dart' as rust_symbolic;
import 'package:calc_flut_rs/shared/widgets/app_chip.dart';
import 'package:calc_flut_rs/shared/widgets/app_dialog.dart';
import 'package:calc_flut_rs/shared/widgets/app_notice.dart';
import 'package:calc_flut_rs/shared/widgets/glass_utils.dart';

/// The Algebra workspace: simplify, expand and factor an expression.
///
/// Reached from the Symbolic Math hub. Follows the calculator's shape — an
/// expression editor on top, a result surface below — rather than inventing a
/// separate layout for symbolic work.
class AlgebraScreen extends ConsumerStatefulWidget {
  const AlgebraScreen({super.key});

  @override
  ConsumerState<AlgebraScreen> createState() => _AlgebraScreenState();
}

class _AlgebraScreenState extends ConsumerState<AlgebraScreen> {
  late final TextEditingController _controller;

  /// Which operation is in flight, so only that chip shows a progress state.
  AlgebraOperation? _computingOperation;

  Timer? _indicatorTimer;
  Timer? _slowCallTimer;

  /// Whether the current call has been slow enough to say so.
  bool _callIsSlow = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: ref.read(algebraProvider).expression,
    );
  }

  @override
  void dispose() {
    _indicatorTimer?.cancel();
    _slowCallTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// Runs [operation], showing feedback only if it turns out to be slow.
  ///
  /// The two timers exist because most algebraic operations finish in
  /// microseconds. Announcing work that has already finished reads as a glitch,
  /// so nothing appears until a call has genuinely run long.
  Future<void> _run(AlgebraOperation operation) async {
    _indicatorTimer?.cancel();
    _slowCallTimer?.cancel();
    setState(() {
      _computingOperation = operation;
      _callIsSlow = false;
    });

    _indicatorTimer = Timer(
      SymbolicComputeTimings.indicatorDelay,
      () {
        if (!mounted) return;
        setState(() => _computingOperation = operation);
      },
    );
    _slowCallTimer = Timer(SymbolicComputeTimings.slowCallNotice, () {
      if (!mounted) return;
      setState(() => _callIsSlow = true);
    });

    final succeeded = await ref.read(algebraProvider.notifier).run(operation);

    _indicatorTimer?.cancel();
    _slowCallTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _computingOperation = null;
      _callIsSlow = false;
    });
    FocusScope.of(context).unfocus();

    if (!succeeded) {
      final error = ref.read(algebraProvider).error;
      if (error != null && mounted) {
        showAppNotice(context, error.message, icon: Icons.error_outline);
      }
    }
  }

  void _copyResult() {
    final value = ref.read(algebraProvider).displayValue;
    if (value.isEmpty) return;
    Clipboard.setData(ClipboardData(text: value));
    showAppNotice(context, 'Result copied', icon: Icons.check);
  }

  /// Lists the operations the backend actually supports.
  ///
  /// The list comes from the bridge rather than a hand-written literal, so it
  /// cannot drift from what the workspace can really do.
  void _showSupportedOperations() {
    List<String> operations;
    try {
      operations = rust_symbolic.symbolicOperations();
    } catch (_) {
      showAppNotice(
        context,
        'Could not load the operation list',
        icon: Icons.error_outline,
      );
      return;
    }

    showAppDialog(
      context: context,
      uiStyle: ref.read(uiStyleProvider),
      title: 'Supported Algebra Operations',
      icon: Icons.functions,
      primaryButtonText: 'OK',
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Each operation is applied to the expression above. The result also '
            'offers the remaining forms as chips, so you can compare them '
            'without retyping anything.',
          ),
          const SizedBox(height: 16),
          for (final operation in AlgebraOperation.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.arrow_right,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          operation.label,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        Text(
                          operation.description,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Text(
            'Reported by the engine: ${operations.join(', ')}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  void _explainLimit() {
    showAppDialog(
      context: context,
      uiStyle: ref.read(uiStyleProvider),
      title: 'Why some expressions are refused',
      icon: Icons.help_outline,
      primaryButtonText: 'Got it',
      content: const Text(
        'Simplification, expansion and factorisation have no natural stopping '
        'point: a single extra pair of brackets can multiply the work needed. '
        'To keep the app responsive, very large expressions are refused rather '
        'than left running.\n\n'
        'Break the problem into smaller steps and apply them one at a time — '
        'the result of each step can be fed straight into the next.',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Keep the field in step with the provider, including history restores.
    ref.listen(algebraProvider.select((state) => state.expression), (
      previous,
      next,
    ) {
      if (_controller.text != next) {
        _controller.value = TextEditingValue(
          text: next,
          selection: TextSelection.collapsed(offset: next.length),
        );
      }
    });

    final state = ref.watch(algebraProvider);
    final uiStyle = ref.watch(uiStyleProvider);
    final theme = Theme.of(context);
    final themeExt = theme.extension<AppThemeExtension>()!;

    return Scaffold(
      appBar: AppBar(title: const Text('Algebra')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // A grid or scroll view cannot lay out against a non-positive
          // extent. The shell builds sections inside an IndexedStack, so the
          // first frame can still measure zero while Android insets settle.
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
                _buildEditor(context, theme, uiStyle),
                const SizedBox(height: 12),
                if (state.variables.isNotEmpty) ...[
                  _buildVariableChips(context, theme, themeExt, state, uiStyle),
                  const SizedBox(height: 12),
                ],
                AlgebraActionRow(
                  uiStyle: uiStyle,
                  state: state,
                  onRun: _run,
                  computingOperation: _computingOperation,
                ),
                if (_callIsSlow) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Still working — this can take a moment for complex expressions',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 16),
                AlgebraResultCard(
                  uiStyle: uiStyle,
                  state: state,
                  onCopy: _copyResult,
                  onShowForm: (index) =>
                      ref.read(algebraProvider.notifier).showForm(index),
                  onExplainLimit: _explainLimit,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEditor(BuildContext context, ThemeData theme, UiStyle uiStyle) {
    return SharedSurface(
      uiStyle: uiStyle,
      glassRole: GlassSurfaceRole.card,
      frosted: true,
      borderRadius: BorderRadius.circular(20),
      padding: const EdgeInsets.all(16),
      child: Stack(
        children: [
          TextField(
            controller: _controller,
            maxLines: 4,
            minLines: 2,
            style: theme.textTheme.headlineSmall,
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: '(x + 1)^2',
              hintStyle: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
              ),
              contentPadding: const EdgeInsets.only(right: 40),
            ),
            onChanged: (value) =>
                ref.read(algebraProvider.notifier).setExpression(value),
          ),
          Positioned(
            top: -8,
            right: -8,
            child: IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: _showSupportedOperations,
              tooltip: 'Supported operations',
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  /// Variable chips, which select the variable an operation acts on.
  ///
  /// These are selectors, not value fields: nothing is substituted, the
  /// variable stays free. That distinction is why a single tap is enough here
  /// and why the row stays empty when the expression has no variables.
  Widget _buildVariableChips(
    BuildContext context,
    ThemeData theme,
    AppThemeExtension themeExt,
    AlgebraState state,
    UiStyle uiStyle,
  ) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final variable in state.variables)
            _VariableChip(
              uiStyle: uiStyle,
              name: variable,
              isSelected: variable == state.selectedVariable,
              onTap: () =>
                  ref.read(algebraProvider.notifier).selectVariable(variable),
            ),
        ],
      ),
    );
  }
}

/// A selectable variable chip.
class _VariableChip extends StatelessWidget {
  final UiStyle uiStyle;
  final String name;
  final bool isSelected;
  final VoidCallback onTap;

  const _VariableChip({
    required this.uiStyle,
    required this.name,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeExt = theme.extension<AppThemeExtension>()!;
    final colorScheme = theme.colorScheme;

    final background = isSelected
        ? colorScheme.primaryContainer
        : themeExt.chipBackground;
    final foreground = isSelected
        ? colorScheme.onPrimaryContainer
        : themeExt.chipText;

    return Tooltip(
      message: isSelected
          ? 'Operations will use $name'
          : 'Use $name for operations that need one variable',
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: AppChip.minimumTouchTarget,
              minHeight: AppChip.minimumTouchTarget,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text(
                name,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: foreground,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w400,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
