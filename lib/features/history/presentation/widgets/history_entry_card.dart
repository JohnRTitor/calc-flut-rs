import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:calc_flut_rs/app/theme/ui_style.dart';
import 'package:calc_flut_rs/features/calculator/presentation/providers/calculator_provider.dart';
import 'package:calc_flut_rs/features/calculator/presentation/providers/function_evaluator_provider.dart';
import 'package:calc_flut_rs/features/calculator/presentation/providers/modular_arithmetic_workspace_provider.dart';
import 'package:calc_flut_rs/features/history/domain/history_category.dart';
import 'package:calc_flut_rs/features/history/presentation/providers/history_provider.dart';
import 'package:calc_flut_rs/features/symbolic_math/presentation/providers/symbolic_history.dart';
import 'package:calc_flut_rs/generated/rust/shared/history.dart';
import 'package:calc_flut_rs/shared/widgets/glass_utils.dart';

/// One saved calculation: its preview, its tool's icon, and the means to
/// reopen or delete it.
///
/// Split out of the history screen because everything here is a function of a
/// single entry, while the screen itself is a function of the *filter*. That
/// split matters more than it used to: the "All" view puts entries from every
/// tool in one list, so a card can no longer assume it knows which tool it
/// belongs to, and resolving that per entry is this widget's job.
class HistoryEntryCard extends ConsumerWidget {
  final HistoryEntry entry;
  final UiStyle uiStyle;

  /// Called after a successful restore, with the tool that was reopened.
  ///
  /// `null` for an entry whose tool this build no longer has, which cannot be
  /// restored. The screen uses a non-null tool to decide whether the caller
  /// waiting on a `Navigator.push` should follow it.
  final ValueChanged<HistoryCategory?> onRestored;

  const HistoryEntryCard({
    super.key,
    required this.entry,
    required this.uiStyle,
    required this.onRestored,
  });

  /// The tool an entry was recorded by, or `null` for a category this build
  /// does not recognise.
  ///
  /// `null` is possible for an entry written by a version of the app that had a
  /// tool this one no longer has. It renders and dismisses normally; it just
  /// cannot be reopened, because there is no workspace to reopen it in.
  static HistoryCategory? toolFor(String storedCategory) {
    for (final tool in HistoryCategory.values) {
      if (tool.matches(storedCategory)) return tool;
    }
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    // Resolve the entry's own tool rather than reading it off the filter: in
    // the "All" view a single list spans every tool, and a card that borrowed
    // the selected tool's icon would be actively wrong.
    final tool = toolFor(entry.category);

    // Parse the preview JSON
    Map<String, dynamic> previewData = {};
    try {
      previewData = jsonDecode(entry.preview);
    } catch (_) {}

    return Dismissible(
      key: ValueKey(entry.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(
          Icons.delete_outline,
          color: theme.colorScheme.onErrorContainer,
        ),
      ),
      onDismissed: (_) {
        ref.read(historyProvider.notifier).delete(entry.id);
      },
      child: SharedSurface(
        uiStyle: uiStyle,
        glassRole: GlassSurfaceRole.card,
        borderRadius: BorderRadius.circular(16),
        padding: EdgeInsets.zero,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _restore(ref, tool),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  tool?.icon ?? Icons.history,
                  size: 20,
                  color: theme.colorScheme.primary.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: _buildPreviewContent(previewData, theme, tool),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildPreviewContent(
    Map<String, dynamic> previewData,
    ThemeData theme,
    HistoryCategory? tool,
  ) {
    switch (tool) {
      case HistoryCategory.calculator:
        return [
          Text(
            previewData['expression']?.toString() ?? '',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.right,
          ),
          const SizedBox(height: 4),
          Text(
            '= ${previewData['result']?.toString() ?? ''}',
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.right,
          ),
        ];
      case HistoryCategory.functionEvaluator:
        return [
          Text(
            previewData['functionDefinition']?.toString() ?? '',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.right,
          ),
          const SizedBox(height: 4),
          Text(
            previewData['expression']?.toString() ?? '',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.right,
          ),
          const SizedBox(height: 4),
          Text(
            '= ${previewData['result']?.toString() ?? ''}',
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.right,
          ),
        ];
      case HistoryCategory.modularArithmetic:
        return [
          Text(
            '${previewData['operation']?.toString() ?? ''} mod ${previewData['modulus']?.toString() ?? ''}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.right,
          ),
          const SizedBox(height: 4),
          Text(
            previewData['inputs']?.toString() ?? '',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.right,
          ),
          const SizedBox(height: 4),
          Text(
            '= ${previewData['result']?.toString() ?? ''}',
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.right,
          ),
        ];
      // Every symbolic tool records the same three preview fields, so the five
      // of them share one branch. They still get five *filters*; only their
      // presentation is common.
      case HistoryCategory.algebra:
      case HistoryCategory.equationSolver:
      case HistoryCategory.calculus:
      case HistoryCategory.matrices:
      case HistoryCategory.numberTheory:
        return [
          Text(
            previewData['operation']?.toString() ?? '',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.right,
          ),
          const SizedBox(height: 4),
          Text(
            previewData['expression']?.toString() ?? '',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.right,
          ),
          const SizedBox(height: 4),
          Text(
            '= ${previewData['result']?.toString() ?? ''}',
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.right,
          ),
        ];
      case null:
        // An entry from a tool this build no longer has. Show what can be read
        // rather than dropping it, so nothing silently disappears.
        return [
          Text(
            previewData['operation']?.toString() ?? '',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.right,
          ),
          const SizedBox(height: 4),
          Text(
            '= ${previewData['result']?.toString() ?? ''}',
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.right,
          ),
        ];
    }
  }

  /// Reopens this entry in the workspace that produced it.
  void _restore(WidgetRef ref, HistoryCategory? tool) {
    switch (tool) {
      case HistoryCategory.calculator:
        ref.read(calculatorProvider.notifier).restoreSnapshot(entry.snapshot);
      case HistoryCategory.functionEvaluator:
        ref
            .read(functionEvaluatorProvider.notifier)
            .restoreSnapshot(entry.snapshot);
      case HistoryCategory.modularArithmetic:
        ref
            .read(modularArithmeticWorkspaceProvider.notifier)
            .restoreSnapshot(entry.snapshot);
      // All five symbolic tools funnel into the one dispatcher, which picks the
      // workspace from the snapshot's own shape rather than from the filter —
      // so restoring a Matrices entry from the "All" view opens Matrices.
      case HistoryCategory.algebra:
      case HistoryCategory.equationSolver:
      case HistoryCategory.calculus:
      case HistoryCategory.matrices:
      case HistoryCategory.numberTheory:
        restoreSymbolicSnapshot(ref, entry.snapshot);
      case null:
        // Nothing to reopen it in; leave the user where they are.
        return;
    }
    onRestored(tool);
  }
}
