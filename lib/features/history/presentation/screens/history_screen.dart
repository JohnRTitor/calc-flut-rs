import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:calc_flut_rs/features/history/domain/history_category.dart';
import 'package:calc_flut_rs/features/history/presentation/providers/history_provider.dart';
import 'package:calc_flut_rs/features/calculator/presentation/providers/calculator_provider.dart';
import 'package:calc_flut_rs/features/calculator/presentation/providers/function_evaluator_provider.dart';
import 'package:calc_flut_rs/features/calculator/presentation/providers/modular_arithmetic_workspace_provider.dart';
import 'package:calc_flut_rs/features/settings/presentation/providers/theme_provider.dart';
import 'package:calc_flut_rs/app/theme/ui_style.dart';
import 'package:calc_flut_rs/shared/widgets/multi_pill_switcher.dart';
import 'package:calc_flut_rs/shared/widgets/app_dialog.dart';
import 'package:calc_flut_rs/shared/widgets/glass_utils.dart';
import 'package:calc_flut_rs/generated/rust/shared/history.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  final HistoryCategory initialCategory;

  const HistoryScreen({super.key, this.initialCategory = HistoryCategory.calculator});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  late HistoryCategory _selectedCategory;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory;
  }

  @override
  Widget build(BuildContext context) {
    final uiStyle = ref.watch(uiStyleProvider);
    final historyAsync = ref.watch(historyProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: 'Clear history for current category',
            onPressed: () async {
              final historyList = ref.read(historyProvider).value ?? [];
              final filteredList = historyList.where((e) => e.category == _selectedCategory.name).toList();
              
              if (filteredList.isEmpty) return;

              final confirm = await _showClearHistoryDialog(
                context,
                filteredList.length,
                uiStyle,
                _selectedCategory.label,
              );
              if (confirm == true) {
                ref.read(historyProvider.notifier).clearCategory(_selectedCategory.name);
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12),
            child: MultiPillSwitcher(
              uiStyle: uiStyle,
              labels: HistoryCategory.values.map((c) => c.label).toList(),
              tooltips: const [
                'Basic calculator history',
                'Function evaluator history',
                'Modular arithmetic history'
              ],
              selectedIndex: HistoryCategory.values.indexOf(_selectedCategory),
              onChanged: (index) {
                setState(() {
                  _selectedCategory = HistoryCategory.values[index];
                });
              },
            ),
          ),
          Expanded(
            child: historyAsync.when(
              data: (history) {
                final filteredHistory = history.where((e) => e.category == _selectedCategory.name).toList();
                
                if (filteredHistory.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _selectedCategory.icon,
                          size: 48,
                          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No ${_selectedCategory.label} history',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                
                return ListView.separated(
                  padding: EdgeInsets.only(
                    left: 12,
                    right: 12,
                    top: 8,
                    bottom: 8 + MediaQuery.paddingOf(context).bottom,
                  ),
                  itemCount: filteredHistory.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final entry = filteredHistory[index];
                    return _buildHistoryCard(context, entry, uiStyle);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error: $err')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(BuildContext context, HistoryEntry entry, UiStyle uiStyle) {
    final theme = Theme.of(context);
    
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
          onTap: () => _restoreSnapshot(entry),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  _selectedCategory.icon,
                  size: 20,
                  color: theme.colorScheme.primary.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: _buildPreviewContent(previewData, theme),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildPreviewContent(Map<String, dynamic> previewData, ThemeData theme) {
    switch (_selectedCategory) {
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
    }
  }

  void _restoreSnapshot(HistoryEntry entry) {
    switch (_selectedCategory) {
      case HistoryCategory.calculator:
        ref.read(calculatorProvider.notifier).restoreSnapshot(entry.snapshot);
        break;
      case HistoryCategory.functionEvaluator:
        ref.read(functionEvaluatorProvider.notifier).restoreSnapshot(entry.snapshot);
        break;
      case HistoryCategory.modularArithmetic:
        ref.read(modularArithmeticWorkspaceProvider.notifier).restoreSnapshot(entry.snapshot);
        break;
    }
    Navigator.pop(context, _selectedCategory);
  }

  Future<bool?> _showClearHistoryDialog(
    BuildContext context,
    int count,
    UiStyle uiStyle,
    String categoryLabel,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return showAppDialog<bool>(
      context: context,
      title: 'Clear $categoryLabel History',
      icon: Icons.delete_outline,
      uiStyle: uiStyle,
      isDestructive: true,
      primaryButtonText: 'Clear',
      onPrimaryButtonPressed: () => Navigator.of(context).pop(true),
      secondaryButtonText: 'Cancel',
      onSecondaryButtonPressed: () => Navigator.of(context).pop(false),
      content: RichText(
        text: TextSpan(
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
            height: 1.5,
          ),
          children: [
            const TextSpan(text: 'This action will permanently remove '),
            TextSpan(
              text: '$count saved calculation${count == 1 ? '' : 's'}',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
              ),
            ),
            const TextSpan(text: ' and cannot be undone.'),
          ],
        ),
      ),
    );
  }
}
