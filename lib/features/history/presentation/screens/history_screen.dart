import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:calc_flut_rs/features/history/domain/history_category.dart';
import 'package:calc_flut_rs/features/history/presentation/providers/history_provider.dart';
import 'package:calc_flut_rs/features/history/presentation/widgets/history_entry_card.dart';
import 'package:calc_flut_rs/features/history/presentation/widgets/history_filter_bar.dart';
import 'package:calc_flut_rs/features/settings/presentation/providers/theme_provider.dart';
import 'package:calc_flut_rs/app/theme/ui_style.dart';
import 'package:calc_flut_rs/shared/widgets/app_dialog.dart';
import 'package:calc_flut_rs/generated/rust/shared/history.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  /// The tool to open filtered to.
  ///
  /// Passing a category also selects its group, so a tool deep-linked to from
  /// its own app bar lands with both rows already resolved.
  final HistoryCategory? initialCategory;

  /// When true the screen is hosted as a top level section inside `AppShell`,
  /// which already renders the title in its app bar. Suppresses this screen's
  /// own app bar so the title is not shown twice.
  final bool embedded;

  const HistoryScreen({super.key, this.initialCategory, this.embedded = false});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  HistoryGroup? _selectedGroup;
  HistoryCategory? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory;
    _selectedGroup = widget.initialCategory?.group;
  }

  @override
  Widget build(BuildContext context) {
    final uiStyle = ref.watch(uiStyleProvider);
    final historyAsync = ref.watch(historyProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: widget.embedded
          ? null
          : AppBar(
              title: const Text('History'),
              actions: [_buildClearButton(uiStyle)],
            ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: HistoryFilterBar(
                    uiStyle: uiStyle,
                    selectedGroup: _selectedGroup,
                    selectedCategory: _selectedCategory,
                    onGroupChanged: (group) => setState(() {
                      _selectedGroup = group;
                      // Changing group drops any tool-level choice, since a
                      // tool from the previous group is not a filter of the
                      // new one.
                      _selectedCategory = null;
                    }),
                    onToolChanged: (category) => setState(() {
                      _selectedCategory = category;
                    }),
                  ),
                ),
                // In embedded mode the shell owns the app bar, so the clear
                // action lives here beside the category filter instead. The
                // filter rows scroll, so taking this width from them cannot
                // truncate a label.
                if (widget.embedded) ...[
                  const SizedBox(width: 4),
                  _buildClearButton(uiStyle),
                ],
              ],
            ),
          ),
          Expanded(
            child: historyAsync.when(
              data: (history) {
                final filteredHistory = history
                    .where(
                      (e) => historyEntryMatches(
                        e.category,
                        group: _selectedGroup,
                        category: _selectedCategory,
                      ),
                    )
                    .toList();

                if (filteredHistory.isEmpty) {
                  return _buildEmptyState(theme);
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

  /// Names the tools the current filter covers, so the empty state can say
  /// what is missing rather than just showing a blank list.
  String get _selectionLabel =>
      historySelectionLabel(group: _selectedGroup, category: _selectedCategory);

  Widget _buildEmptyState(ThemeData theme) {
    final icon = _selectedCategory?.icon ?? _selectedGroup?.icon;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null)
            Icon(
              icon,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
            ),
          const SizedBox(height: 12),
          Text(
            _selectedCategory == null && _selectedGroup == null
                ? 'No history yet'
                : 'No $_selectionLabel history',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ),
          if (_selectedCategory == null && _selectedGroup == null) ...[
            const SizedBox(height: 6),
            Text(
              'Results you compute in any tool are saved here.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.4,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildClearButton(UiStyle uiStyle) {
    return IconButton(
      icon: const Icon(Icons.delete_sweep_outlined),
      tooltip: 'Clear history for current category',
      onPressed: () async {
        final historyList = ref.read(historyProvider).value ?? [];
        final filteredList = historyList
            .where(
              (e) => historyEntryMatches(
                e.category,
                group: _selectedGroup,
                category: _selectedCategory,
              ),
            )
            .toList();

        if (filteredList.isEmpty) return;

        final confirm = await _showClearHistoryDialog(
          context,
          filteredList.length,
          uiStyle,
          _selectionLabel,
        );
        if (confirm != true) return;

        // Clear the names that are *actually on disk*, not the names this build
        // writes. They are not the same set: entries predating the split are
        // stored under the shared `symbolic` name, and entries from a tool this
        // build no longer has are stored under names nothing here knows. Clearing
        // the current enum instead would report success and leave every one of
        // those in place — the list would refill the moment it refreshed, and
        // the user would watch a delete do nothing.
        final storedNames = {for (final entry in filteredList) entry.category};
        for (final name in storedNames) {
          ref.read(historyProvider.notifier).clearCategory(name);
        }
      },
    );
  }

  Widget _buildHistoryCard(
    BuildContext context,
    HistoryEntry entry,
    UiStyle uiStyle,
  ) {
    return HistoryEntryCard(
      entry: entry,
      uiStyle: uiStyle,
      onRestored: (tool) {
        // Only a tool-level filter has anything to hand back. Restoring from
        // the "All" view or a group view must not silently change the tab a
        // caller is showing.
        if (tool != null) Navigator.pop(context, tool);
      },
    );
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
