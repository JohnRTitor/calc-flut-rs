import 'package:flutter/material.dart';

import 'package:calc_flut_rs/app/theme/ui_style.dart';
import 'package:calc_flut_rs/generated/rust/bridge/modular_arithmetic.dart';
import 'package:calc_flut_rs/shared/layouts/breakpoints.dart';
import 'package:calc_flut_rs/shared/widgets/app_dialog.dart';
import 'package:calc_flut_rs/features/calculator/presentation/widgets/modular_arithmetic/cayley_table_view.dart';
import 'package:calc_flut_rs/features/calculator/presentation/widgets/modular_arithmetic/modular_analysis_metrics.dart';
import 'package:calc_flut_rs/features/calculator/presentation/widgets/modular_arithmetic/modular_analysis_table.dart';

/// The structure of a ring, group or field, as a summary grid plus the detail
/// behind each figure.
///
/// The summary tiles are the only index there is, and each one *is* its
/// section's expand/collapse trigger. The two used to be separate: a tile
/// showed "Zero Divisors: 31" and a section below showed "Zero Divisors — 31
/// items", so the same number appeared twice with nothing joining them.
///
/// They were wired together, but the wiring did not work. Tapping a tile set
/// the section's `isExpanded` flag and passed it to an `ExpansionTile` as
/// `initiallyExpanded` — a parameter Flutter reads once, at construction. After
/// the first frame it is ignored, so the tap scrolled to a section that stayed
/// shut: an affordance that looked live and did nothing. Hence the controlled
/// section below, which has no such one-shot parameter.
class ModularArithmeticAnalysisGrid extends StatefulWidget {
  final UiStyle uiStyle;
  final StructureAnalysis analysis;
  final String? interpretedAs;

  const ModularArithmeticAnalysisGrid({
    super.key,
    required this.uiStyle,
    required this.analysis,
    this.interpretedAs,
  });

  @override
  State<ModularArithmeticAnalysisGrid> createState() =>
      _ModularArithmeticAnalysisGridState();
}

/// The detail sections a summary tile can open.
///
/// Ordered as they appear in the summary, so the two read as one list.
enum _Detail {
  generators,
  units,
  zeroDivisors,
  idempotents,
  nilpotents,
  inverses,
  elementOrders,
  cayleyTable,
}

class _ModularArithmeticAnalysisGridState
    extends State<ModularArithmeticAnalysisGrid> {
  final Set<_Detail> _expanded = <_Detail>{};

  final Map<_Detail, GlobalKey> _sectionKeys = {
    for (final detail in _Detail.values) detail: GlobalKey(),
  };

  /// The sections this analysis actually has content for.
  ///
  /// A tile with nothing behind it is not a trigger, and a section with no tile
  /// would be unreachable — so both are derived from this one list.
  List<_Detail> get _availableDetails {
    final analysis = widget.analysis;
    return [
      if (analysis.generators.isNotEmpty) _Detail.generators,
      if (analysis.units.isNotEmpty) _Detail.units,
      if (analysis.zeroDivisors.isNotEmpty) _Detail.zeroDivisors,
      if (analysis.idempotents.isNotEmpty) _Detail.idempotents,
      if (analysis.nilpotents.isNotEmpty) _Detail.nilpotents,
      if (analysis.inverses.isNotEmpty) _Detail.inverses,
      if (analysis.elementOrders.isNotEmpty) _Detail.elementOrders,
      if (analysis.cayleyTable != null) _Detail.cayleyTable,
    ];
  }

  /// Opens or closes a section, then brings it into view when opening.
  ///
  /// The scroll is deferred by one frame because the section is taller when
  /// expanded, and scrolling to a position computed against the collapsed
  /// height would land in the wrong place.
  void _toggle(_Detail detail) {
    final isNowOpen = !_expanded.contains(detail);
    setState(() {
      if (isNowOpen) {
        _expanded.add(detail);
      } else {
        _expanded.remove(detail);
      }
    });

    if (!isNowOpen) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _sectionKeys[detail]?.currentContext;
      if (context == null || !mounted) return;
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        alignment: 0.05,
      );
    });
  }

  void _showTruncationInfo() {
    showAppDialog(
      context: context,
      uiStyle: widget.uiStyle,
      title: 'Data Truncated',
      icon: Icons.info_outline_rounded,
      content: const Text(
        'Because this mathematical structure is very large, detailed lists of '
        'elements (such as inverses or zero divisors) have been capped at '
        '10,000 items to preserve app performance. The counts shown in the '
        'metrics grid represent the true mathematical counts.',
      ),
      primaryButtonText: 'Understood',
      onPrimaryButtonPressed: () => Navigator.of(context).pop(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isField = widget.analysis.classification.toLowerCase().contains(
      'field',
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.interpretedAs != null) ...[
          Text(
            widget.interpretedAs!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: LayoutMetrics.standard.spacing),
        ],
        if (widget.analysis.isTruncated) ...[
          ModularAnalysisTruncationNotice(
            uiStyle: widget.uiStyle,
            onExplain: _showTruncationInfo,
          ),
          SizedBox(height: LayoutMetrics.standard.spacing),
        ],
        _buildSummaryGrid(context, isField ? 'Field' : 'Ring'),
        SizedBox(height: LayoutMetrics.standard.spacing * 2),
        for (final detail in _availableDetails) _buildSection(context, detail),
      ],
    );
  }

  Widget _buildSummaryGrid(BuildContext context, String typeStr) {
    final analysis = widget.analysis;
    final tiles = <Widget>[
      ModularAnalysisMetricTile(
        uiStyle: widget.uiStyle,
        title: 'Type:',
        value: typeStr,
      ),
      ModularAnalysisMetricTile(
        uiStyle: widget.uiStyle,
        title: 'Elements:',
        value: analysis.order,
      ),
      ModularAnalysisMetricTile(
        uiStyle: widget.uiStyle,
        title: 'Generators:',
        value: analysis.generators.length.toString(),
        onTap: _availableDetails.contains(_Detail.generators)
            ? () => _toggle(_Detail.generators)
            : null,
        isExpanded: _expanded.contains(_Detail.generators),
      ),
      ModularAnalysisMetricTile(
        uiStyle: widget.uiStyle,
        title: 'Units:',
        value: analysis.unitsCount,
        onTap: _availableDetails.contains(_Detail.units)
            ? () => _toggle(_Detail.units)
            : null,
        isExpanded: _expanded.contains(_Detail.units),
      ),
      ModularAnalysisMetricTile(
        uiStyle: widget.uiStyle,
        title: 'Zero Divisors:',
        value: analysis.zeroDivisorsCount,
        onTap: _availableDetails.contains(_Detail.zeroDivisors)
            ? () => _toggle(_Detail.zeroDivisors)
            : null,
        isExpanded: _expanded.contains(_Detail.zeroDivisors),
      ),
      ModularAnalysisMetricTile(
        uiStyle: widget.uiStyle,
        title: 'Idempotents:',
        value: analysis.idempotentsCount,
        onTap: _availableDetails.contains(_Detail.idempotents)
            ? () => _toggle(_Detail.idempotents)
            : null,
        isExpanded: _expanded.contains(_Detail.idempotents),
      ),
      ModularAnalysisMetricTile(
        uiStyle: widget.uiStyle,
        title: 'Nilpotents:',
        value: analysis.nilpotentsCount,
        onTap: _availableDetails.contains(_Detail.nilpotents)
            ? () => _toggle(_Detail.nilpotents)
            : null,
        isExpanded: _expanded.contains(_Detail.nilpotents),
      ),
      ModularAnalysisMetricTile(
        uiStyle: widget.uiStyle,
        title: 'Inverses:',
        value: analysis.inverses.length.toString(),
        onTap: _availableDetails.contains(_Detail.inverses)
            ? () => _toggle(_Detail.inverses)
            : null,
        isExpanded: _expanded.contains(_Detail.inverses),
      ),
      // Every section needs a tile, or it has no way to be opened. The Cayley
      // table in particular used to be pinned open with its own header, so
      // dropping that header without adding a tile here would have made it
      // unreachable — a table the app computes and then never shows.
      ModularAnalysisMetricTile(
        uiStyle: widget.uiStyle,
        title: 'Element Orders:',
        value: analysis.elementOrders.length.toString(),
        onTap: _availableDetails.contains(_Detail.elementOrders)
            ? () => _toggle(_Detail.elementOrders)
            : null,
        isExpanded: _expanded.contains(_Detail.elementOrders),
      ),
      ModularAnalysisMetricTile(
        uiStyle: widget.uiStyle,
        title: 'Cayley Table:',
        value: analysis.cayleyTable == null ? '—' : '1',
        onTap: _availableDetails.contains(_Detail.cayleyTable)
            ? () => _toggle(_Detail.cayleyTable)
            : null,
        isExpanded: _expanded.contains(_Detail.cayleyTable),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 8.0;
        final columns = constraints.maxWidth > 600 ? 3 : 2;
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final tile in tiles) SizedBox(width: width, child: tile),
          ],
        );
      },
    );
  }

  /// One detail section, shown only when its tile has opened it.
  ///
  /// Carries no header of its own. Repeating the tile's title and count here is
  /// exactly the duplication this arrangement exists to remove; the tile is
  /// labelled, and it is the control.
  Widget _buildSection(BuildContext context, _Detail detail) {
    if (!_expanded.contains(detail)) return const SizedBox.shrink();

    final analysis = widget.analysis;
    final Widget body = switch (detail) {
      _Detail.generators => ModularAnalysisDataChips(
        items: analysis.generators,
      ),
      _Detail.units => ModularAnalysisDataChips(items: analysis.units),
      _Detail.zeroDivisors => ModularAnalysisDataChips(
        items: analysis.zeroDivisors,
      ),
      _Detail.idempotents => ModularAnalysisDataChips(
        items: analysis.idempotents,
      ),
      _Detail.nilpotents => ModularAnalysisDataChips(
        items: analysis.nilpotents,
      ),
      _Detail.inverses => ModularAnalysisTable(
        uiStyle: widget.uiStyle,
        columnTitles: const ['Element (a)', 'Inverse (a⁻¹)'],
        rows: [
          for (final pair in analysis.inverses) [pair.element, pair.inverse],
        ],
      ),
      _Detail.elementOrders => ModularAnalysisTable(
        uiStyle: widget.uiStyle,
        columnTitles: const ['Element (a)', 'Order (k)'],
        rows: [
          for (final pair in analysis.elementOrders) [pair.element, pair.order],
        ],
      ),
      _Detail.cayleyTable => CayleyTableView(
        uiStyle: widget.uiStyle,
        cayleyTable: analysis.cayleyTable!,
        identity: analysis.identity,
        inverses: analysis.inverses,
      ),
    };

    return Padding(
      key: _sectionKeys[detail],
      padding: const EdgeInsets.only(bottom: 12),
      child: body,
    );
  }
}
