import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:calc_flut_rs/features/settings/presentation/providers/theme_provider.dart';
import 'package:calc_flut_rs/features/symbolic_math/domain/symbolic_operation.dart';
import 'package:calc_flut_rs/features/symbolic_math/presentation/providers/symbolic_workspace.dart';
import 'package:calc_flut_rs/features/symbolic_math/presentation/providers/symbolic_workspace_state.dart';
import 'symbolic_action_row.dart';
import 'symbolic_expression_editor.dart';
import 'symbolic_help_dialog.dart';
import 'symbolic_plot_sheet.dart';
import 'symbolic_result_card.dart';
import 'package:calc_flut_rs/generated/rust/bridge/symbolic.dart' as rust_symbolic;
import 'package:calc_flut_rs/shared/widgets/app_notice.dart';

/// Thresholds that govern when a workspace admits it is working.
///
/// Named rather than inlined so the feel can be tuned after release without
/// hunting through build methods.
class SymbolicComputeTimings {
  const SymbolicComputeTimings._();

  /// How long a call may run before a progress indicator appears.
  ///
  /// Almost every algebraic operation resolves in well under this, and a
  /// spinner that flashes for 30ms reads as a glitch rather than as feedback.
  /// Nothing is shown until a call is genuinely slow.
  static const Duration indicatorDelay = Duration(milliseconds: 150);

  /// How long a call may run before a reassurance line appears.
  ///
  /// Symbolic work has no hard upper bound, so past this point the user is told
  /// it is still running rather than being left guessing whether the tap
  /// registered.
  static const Duration slowCallNotice = Duration(seconds: 8);
}

/// The shared screen every tool in the Symbolic Math section is built from.
///
/// Owns the layout, the computing-feedback timers, and the reference dialog, so
/// a new tool in this section is a handful of lines plus a registry entry. Each
/// host passes its own provider, which keeps tool state independent while the
/// behaviour stays in one place.
class SymbolicWorkspaceScaffold extends ConsumerStatefulWidget {
  /// App bar title. Must match the tool's hub card label.
  final String title;

  /// Placeholder shown in the expression field while it is empty.
  final String hintText;

  /// The workspace this screen drives.
  final NotifierProvider<SymbolicWorkspace, SymbolicWorkspaceState> provider;

  /// The operations this tool offers, used by the reference dialog.
  final List<SymbolicOperation> operations;

  /// Extra controls shown directly beneath the expression editor.
  ///
  /// A slot rather than a subclass, so a tool that needs one more input — the
  /// Calculus workspace's integral bounds, say — does not have to copy this
  /// whole layout. Deliberately a widget rather than a list of extra fields, so
  /// the host decides what its inputs look like.
  final Widget? extraControls;

  const SymbolicWorkspaceScaffold({
    super.key,
    required this.title,
    required this.hintText,
    required this.provider,
    required this.operations,
    this.extraControls,
  });

  @override
  ConsumerState<SymbolicWorkspaceScaffold> createState() =>
      _SymbolicWorkspaceScaffoldState();
}

class _SymbolicWorkspaceScaffoldState
    extends ConsumerState<SymbolicWorkspaceScaffold> {
  /// Which operation is in flight, so only that chip shows a progress state.
  SymbolicOperation? _computingOperation;

  Timer? _indicatorTimer;
  Timer? _slowCallTimer;

  /// Whether the current call has been slow enough to say so.
  bool _callIsSlow = false;

  @override
  void dispose() {
    _indicatorTimer?.cancel();
    _slowCallTimer?.cancel();
    super.dispose();
  }

  /// Runs [operation], showing feedback only if it turns out to be slow.
  ///
  /// The two timers exist because most algebraic operations finish in
  /// microseconds. Announcing work that has already finished reads as a glitch,
  /// so nothing appears until a call has genuinely run long.
  Future<void> _run(SymbolicOperation operation) async {
    _indicatorTimer?.cancel();
    _slowCallTimer?.cancel();
    setState(() {
      _computingOperation = operation;
      _callIsSlow = false;
    });

    _indicatorTimer = Timer(SymbolicComputeTimings.indicatorDelay, () {
      if (!mounted) return;
      setState(() => _computingOperation = operation);
    });
    _slowCallTimer = Timer(SymbolicComputeTimings.slowCallNotice, () {
      if (!mounted) return;
      setState(() => _callIsSlow = true);
    });

    final succeeded = await ref
        .read(widget.provider.notifier)
        .run(operation);

    _indicatorTimer?.cancel();
    _slowCallTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _computingOperation = null;
      _callIsSlow = false;
    });
    FocusScope.of(context).unfocus();

    if (!succeeded) {
      final error = ref.read(widget.provider).error;
      if (error != null && mounted) {
        showAppNotice(context, error.message, icon: Icons.error_outline);
      }
    }
  }

  void _copyResult() {
    final value = ref.read(widget.provider).displayValue;
    if (value.isEmpty) return;
    Clipboard.setData(ClipboardData(text: value));
    showAppNotice(context, 'Result copied', icon: Icons.check);
  }

  /// Draws the current expression, for a function of one variable.
  void _plot() {
    final state = ref.read(widget.provider);
    final variable = state.selectedVariable;
    if (variable == null) return;
    showSymbolicPlotSheet(
      context: context,
      uiStyle: ref.read(uiStyleProvider),
      expression: state.expression,
      variable: variable,
    );
  }

  /// Explains what this tool offers and how much its answers can be trusted.
  ///
  /// The chip labels come from the same enum that drives the action row, and the
  /// engine is asked what it supports, so the dialog cannot drift from either.
  void _showSupportedOperations() {
    List<String> reportedByEngine;
    try {
      reportedByEngine = rust_symbolic.symbolicOperations();
    } catch (_) {
      showAppNotice(
        context,
        'Could not load the operation list',
        icon: Icons.error_outline,
      );
      return;
    }

    final names = widget.operations.map((operation) => operation.label).join(', ');
    showSymbolicHelpDialog(
      context: context,
      uiStyle: ref.read(uiStyleProvider),
      title: 'Supported Operations',
      description: 'Applied to the expression above. This tool offers: '
          '$names. Results also include the other equivalent forms of the same '
          'expression as chips, so you can compare them without retyping.',
      notes: [
        for (final operation in widget.operations)
          '${operation.label} — ${operation.description}',
        'Results stay exact: 1/3 rather than 0.333, sqrt(2) rather than 1.41.',
        'The engine reports these operations in total: ${reportedByEngine.join(', ')}.',
      ],
    );
  }

  void _explainLimit() {
    showSymbolicHelpDialog(
      context: context,
      uiStyle: ref.read(uiStyleProvider),
      title: 'Why some expressions are refused',
      description:
          'Symbolic work has no natural stopping point: a single extra pair of '
          'brackets can multiply the work needed. To keep the app responsive, '
          'very large expressions are refused rather than left running. Some '
          'operations also have no symbolic form at all; those are reported as '
          'unsupported rather than answered with a half-finished expression.',
      notes: const [
        'Break the problem into smaller steps and apply them one at a time — the '
            'result of each step can be fed straight into the next.',
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(widget.provider);
    final uiStyle = ref.watch(uiStyleProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // A scroll view cannot lay out against a non-positive extent. The
          // shell builds sections inside an IndexedStack, so the first frame
          // can still measure zero while Android insets settle.
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
                SymbolicExpressionEditor(
                  uiStyle: uiStyle,
                  expression: state.expression,
                  hintText: widget.hintText,
                  onChanged: (value) =>
                      ref.read(widget.provider.notifier).setExpression(value),
                  onShowHelp: _showSupportedOperations,
                ),
                const SizedBox(height: 12),
                if (widget.extraControls != null) ...[
                  widget.extraControls!,
                  const SizedBox(height: 12),
                ],
                SymbolicVariableSelector(
                  uiStyle: uiStyle,
                  variables: state.variables,
                  selectedVariable: state.selectedVariable,
                  onSelected: (variable) => ref
                      .read(widget.provider.notifier)
                      .selectVariable(variable),
                ),
                SymbolicActionRow(
                  uiStyle: uiStyle,
                  state: state,
                  onRun: _run,
                  computingOperation: _computingOperation,
                ),
                if (_callIsSlow) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Still working — this can take a moment for complex '
                    'expressions',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 16),
                SymbolicResultCard(
                  uiStyle: uiStyle,
                  state: state,
                  onCopy: _copyResult,
                  onShowForm: (index) =>
                      ref.read(widget.provider.notifier).showForm(index),
                  onExplainLimit: _explainLimit,
                  onPlot: _plot,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
