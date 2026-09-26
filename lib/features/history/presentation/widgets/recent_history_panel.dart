import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:calc_flut_rs/app/theme/app_theme_extension.dart';
import 'package:calc_flut_rs/app/theme/ui_style.dart';
import 'package:calc_flut_rs/features/history/domain/history_category.dart';
import 'package:calc_flut_rs/features/history/presentation/providers/history_provider.dart';
import 'package:calc_flut_rs/features/history/presentation/widgets/history_entry_card.dart';
import 'package:calc_flut_rs/features/settings/presentation/providers/theme_provider.dart';
import 'package:calc_flut_rs/generated/rust/shared/history.dart';
import 'package:calc_flut_rs/shared/widgets/glass_utils.dart';

/// One tool's recent results, beside its workspace.
///
/// Shown only on a desktop-class window, where the width would otherwise go to
/// making keys and cards wider. It answers the question a person doing repeated
/// work in one tool actually has — "what did I compute a moment ago in
/// *here*?" — without leaving the tool to find the global History section and
/// pick a chip.
///
/// Reuses [HistoryEntryCard], so an entry restores exactly as it does from the
/// History screen: same dispatch, same snapshot, same behaviour. The only
/// differences are that a panel is not the top of a navigation stack, so it
/// does not pop, and that it shows a bounded number of entries, because a list
/// of everything is what the History screen is for.
class RecentHistoryPanel extends ConsumerStatefulWidget {
  /// The tool whose results belong here.
  final HistoryCategory category;

  /// Most entries to show. The panel is a glance, not a browser.
  final int limit;

  const RecentHistoryPanel({super.key, required this.category, this.limit = 8});

  @override
  ConsumerState<RecentHistoryPanel> createState() => _RecentHistoryPanelState();
}

class _RecentHistoryPanelState extends ConsumerState<RecentHistoryPanel> {
  /// Whether the panel is showing its list or only its header.
  ///
  /// Collapsed by the user, not by the layout: on a wide window the panel is
  /// offered, not imposed, and a person who wants the full width back should
  /// not have to leave the tool to get it.
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    final uiStyle = ref.watch(uiStyleProvider);
    final theme = Theme.of(context);
    final themeExt = theme.extension<AppThemeExtension>()!;
    final history = ref.watch(historyProvider);

    return SharedSurface(
      uiStyle: uiStyle,
      glassRole: GlassSurfaceRole.panel,
      frosted: true,
      borderRadius: BorderRadius.circular(24),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(context, theme, themeExt, uiStyle),
          if (_isExpanded) ...[
            const SizedBox(height: 8),
            Expanded(child: _buildList(context, uiStyle, history)),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    ThemeData theme,
    AppThemeExtension themeExt,
    UiStyle uiStyle,
  ) {
    return Row(
      children: [
        Icon(widget.category.icon, size: 18, color: themeExt.chipText),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Recent in ${widget.category.label}',
            style: theme.textTheme.labelLarge?.copyWith(
              color: themeExt.chipText,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        IconButton(
          icon: Icon(
            _isExpanded ? Icons.expand_less : Icons.expand_more,
            size: 20,
          ),
          // Named, so the control says what it does rather than showing a bare
          // chevron whose meaning depends on having tapped it before.
          tooltip: _isExpanded ? 'Hide recent results' : 'Show recent results',
          onPressed: () => setState(() => _isExpanded = !_isExpanded),
          color: themeExt.chipText,
        ),
      ],
    );
  }

  Widget _buildList(
    BuildContext context,
    UiStyle uiStyle,
    AsyncValue<List<HistoryEntry>> history,
  ) {
    return history.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Text(
          'Could not load history',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
      data: (entries) {
        final mine = entries
            .where((e) => widget.category.matches(e.category))
            .take(widget.limit)
            .toList();

        if (mine.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'Nothing computed here yet',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: onGlassSecondary(context, uiStyle),
                ),
              ),
            ),
          );
        }

        return ListView.separated(
          padding: EdgeInsets.zero,
          itemCount: mine.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final entry = mine[index];
            return HistoryEntryCard(
              entry: entry,
              uiStyle: uiStyle,
              // The panel is not a route, so there is nothing to pop. The
              // workspace is still restored — the user's work is never lost by
              // looking at it in a second place.
              onRestored: (_) {},
            );
          },
        );
      },
    );
  }
}
