import 'package:flutter/material.dart';

import 'package:calc_flut_rs/app/theme/ui_style.dart';
import 'package:calc_flut_rs/shared/layouts/breakpoints.dart';
import 'package:calc_flut_rs/shared/widgets/glass_utils.dart';

/// A two-column table of element/derived-value pairs, as the ring analysis
/// needs for inverses and element orders.
///
/// One widget for both, because they were the same table with two different
/// column titles.
///
/// The header row is a **sibling of the rows, not a row among them**: the rows
/// live in their own scrollable box below it, so the column titles stay put
/// however far the user scrolls. That is deliberate — a header that scrolls out
/// of a 24-row table takes with it the only thing explaining what the numbers
/// are — and it is why this cannot simply be a `Table` inside the page's own
/// scroll view.
///
/// The row list is bounded rather than infinite, which keeps the table from
/// pushing everything else off screen. It also means this is a scroll container
/// nested inside the page's, so the bound is kept modest and the page can
/// always reach the rest of the analysis by scrolling past it.
class ModularAnalysisTable extends StatelessWidget {
  final UiStyle uiStyle;

  /// Column titles, in order. Always two.
  final List<String> columnTitles;

  /// One entry per row, each already formatted for display.
  final List<List<String>> rows;

  /// Largest height the row list may occupy before it scrolls internally.
  static const double maxBodyHeight = 400.0;

  const ModularAnalysisTable({
    super.key,
    required this.uiStyle,
    required this.columnTitles,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SharedSurface(
      uiStyle: uiStyle,
      glassRole: GlassSurfaceRole.card,
      borderRadius: BorderRadius.circular(LayoutMetrics.compact.borderRadius),
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(context, theme),
          Flexible(child: _buildRows()),
        ],
      ),
    );
  }

  /// The pinned column titles.
  ///
  /// Uses the theme's own label style rather than an inline
  /// `TextStyle(fontWeight: bold)`, which resolved to the default black in one
  /// brightness and to nothing legible in the other.
  Widget _buildHeader(BuildContext context, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
      child: Row(
        children: [
          for (final title in columnTitles)
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: onGlassEmphasis(context, uiStyle),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRows() {
    // Sized to its content when it is short, bounded when it is not, so a
    // three-row table does not leave a hole in the page.
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: maxBodyHeight),
      child: ListView.builder(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        itemCount: rows.length,
        itemBuilder: (context, index) {
          final row = rows[index];
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: index == 0
                  ? null
                  : Border(
                      top: BorderSide(
                        color: Theme.of(
                          context,
                        ).colorScheme.outlineVariant.withValues(alpha: 0.3),
                      ),
                    ),
            ),
            child: Row(
              children: [
                for (final cell in row)
                  Expanded(
                    child: Text(
                      cell,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
