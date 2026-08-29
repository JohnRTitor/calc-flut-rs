import 'package:flutter/material.dart';
import 'package:calc_flut_rs/app/theme/ui_style.dart';
import 'package:calc_flut_rs/generated/rust/bridge/modular_arithmetic.dart';
import 'package:calc_flut_rs/shared/widgets/glass_utils.dart';
import 'package:calc_flut_rs/shared/widgets/app_dialog.dart';
import 'package:calc_flut_rs/features/calculator/presentation/widgets/modular_arithmetic/cayley_table_view.dart';

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

class _ModularArithmeticAnalysisGridState
    extends State<ModularArithmeticAnalysisGrid> {
  final ScrollController _scrollController = ScrollController();

  final GlobalKey _generatorsKey = GlobalKey();
  final GlobalKey _unitsKey = GlobalKey();
  final GlobalKey _zeroDivisorsKey = GlobalKey();
  final GlobalKey _idempotentsKey = GlobalKey();
  final GlobalKey _nilpotentsKey = GlobalKey();
  final GlobalKey _inversesKey = GlobalKey();
  final GlobalKey _elementOrdersKey = GlobalKey();

  bool _generatorsExpanded = false;
  bool _unitsExpanded = false;
  bool _zeroDivisorsExpanded = false;
  bool _idempotentsExpanded = false;
  bool _nilpotentsExpanded = false;
  bool _inversesExpanded = false;
  bool _elementOrdersExpanded = false;

  void _scrollToAndExpand(GlobalKey key, Function() expandAction) {
    expandAction();
    // Allow time for expansion animation before scrolling
    Future.delayed(const Duration(milliseconds: 300), () {
      if (key.currentContext != null) {
        Scrollable.ensureVisible(
          key.currentContext!,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          alignment: 0.1, // Scroll so it's near the top
        );
      }
    });
  }

  void _showTruncationInfo() {
    showAppDialog(
      context: context,
      uiStyle: widget.uiStyle,
      title: 'Data Truncated',
      icon: Icons.info_outline_rounded,
      content: const Text(
          'Because this mathematical structure is very large, detailed lists of elements (such as inverses or zero divisors) have been capped at 10,000 items to preserve app performance. The counts shown in the metrics grid represent the true mathematical counts.'),
      primaryButtonText: 'Understood',
      onPrimaryButtonPressed: () => Navigator.of(context).pop(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isField = widget.analysis.classification.toLowerCase().contains('field');
    final typeStr = isField ? 'Field' : 'Ring';

    return SingleChildScrollView(
      controller: _scrollController,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.interpretedAs != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Text(
                widget.interpretedAs!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          if (widget.analysis.isTruncated)
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: SharedSurface(
                uiStyle: widget.uiStyle,
                glassRole: GlassSurfaceRole.accent,
                frosted: true,
                padding: const EdgeInsets.all(12),
                borderRadius: BorderRadius.circular(12),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: theme.colorScheme.error),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Large dataset: Item lists are capped at 10,000.',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    TextButton(
                      onPressed: _showTruncationInfo,
                      child: const Text('Learn More'),
                    ),
                  ],
                ),
              ),
            ),
          Text(
            'Statistics Grid',
            style: theme.textTheme.titleMedium?.copyWith(
              color: widget.uiStyle == UiStyle.liquidGlass
                  ? Colors.white70
                  : theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              int crossAxisCount = constraints.maxWidth > 600 ? 3 : 2;
              double width = (constraints.maxWidth - (8 * (crossAxisCount - 1))) /
                  crossAxisCount;

              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  SizedBox(
                    width: width,
                    child: _MetricCard(
                      uiStyle: widget.uiStyle,
                      title: 'Type:',
                      value: typeStr,
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _MetricCard(
                      uiStyle: widget.uiStyle,
                      title: 'Elements:',
                      value: widget.analysis.order,
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _MetricCard(
                      uiStyle: widget.uiStyle,
                      title: 'Generators:',
                      value: widget.analysis.generators.length.toString(),
                      onTap: widget.analysis.generators.isNotEmpty
                          ? () => _scrollToAndExpand(_generatorsKey, () {
                                setState(() => _generatorsExpanded = true);
                              })
                          : null,
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _MetricCard(
                      uiStyle: widget.uiStyle,
                      title: 'Units:',
                      value: widget.analysis.unitsCount,
                      onTap: widget.analysis.units.isNotEmpty
                          ? () => _scrollToAndExpand(_unitsKey, () {
                                setState(() => _unitsExpanded = true);
                              })
                          : null,
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _MetricCard(
                      uiStyle: widget.uiStyle,
                      title: 'Zero Divisors:',
                      value: widget.analysis.zeroDivisorsCount,
                      onTap: widget.analysis.zeroDivisors.isNotEmpty
                          ? () => _scrollToAndExpand(_zeroDivisorsKey, () {
                                setState(() => _zeroDivisorsExpanded = true);
                              })
                          : null,
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _MetricCard(
                      uiStyle: widget.uiStyle,
                      title: 'Idempotents:',
                      value: widget.analysis.idempotentsCount,
                      onTap: widget.analysis.idempotents.isNotEmpty
                          ? () => _scrollToAndExpand(_idempotentsKey, () {
                                setState(() => _idempotentsExpanded = true);
                              })
                          : null,
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _MetricCard(
                      uiStyle: widget.uiStyle,
                      title: 'Nilpotents:',
                      value: widget.analysis.nilpotentsCount,
                      onTap: widget.analysis.nilpotents.isNotEmpty
                          ? () => _scrollToAndExpand(_nilpotentsKey, () {
                                setState(() => _nilpotentsExpanded = true);
                              })
                          : null,
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _MetricCard(
                      uiStyle: widget.uiStyle,
                      title: 'Inverses:',
                      value: widget.analysis.inverses.length.toString(),
                      onTap: widget.analysis.inverses.isNotEmpty
                          ? () => _scrollToAndExpand(_inversesKey, () {
                                setState(() => _inversesExpanded = true);
                              })
                          : null,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 32),
          Text(
            'Detailed Structure',
            style: theme.textTheme.titleMedium?.copyWith(
              color: widget.uiStyle == UiStyle.liquidGlass
                  ? Colors.white70
                  : theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          if (widget.analysis.generators.isNotEmpty)
            _ExpandableDataSection(
              key: _generatorsKey,
              uiStyle: widget.uiStyle,
              title: 'Generators',
              count: widget.analysis.generators.length.toString(),
              isExpanded: _generatorsExpanded,
              onExpansionChanged: (val) =>
                  setState(() => _generatorsExpanded = val),
              child: _DataChipGrid(items: widget.analysis.generators),
            ),
          if (widget.analysis.units.isNotEmpty)
            _ExpandableDataSection(
              key: _unitsKey,
              uiStyle: widget.uiStyle,
              title: 'Units',
              count: widget.analysis.unitsCount,
              isExpanded: _unitsExpanded,
              onExpansionChanged: (val) => setState(() => _unitsExpanded = val),
              child: _DataChipGrid(items: widget.analysis.units),
            ),
          if (widget.analysis.zeroDivisors.isNotEmpty)
            _ExpandableDataSection(
              key: _zeroDivisorsKey,
              uiStyle: widget.uiStyle,
              title: 'Zero Divisors',
              count: widget.analysis.zeroDivisorsCount,
              isExpanded: _zeroDivisorsExpanded,
              onExpansionChanged: (val) =>
                  setState(() => _zeroDivisorsExpanded = val),
              child: _DataChipGrid(items: widget.analysis.zeroDivisors),
            ),
          if (widget.analysis.idempotents.isNotEmpty)
            _ExpandableDataSection(
              key: _idempotentsKey,
              uiStyle: widget.uiStyle,
              title: 'Idempotents',
              count: widget.analysis.idempotentsCount,
              isExpanded: _idempotentsExpanded,
              onExpansionChanged: (val) =>
                  setState(() => _idempotentsExpanded = val),
              child: _DataChipGrid(items: widget.analysis.idempotents),
            ),
          if (widget.analysis.nilpotents.isNotEmpty)
            _ExpandableDataSection(
              key: _nilpotentsKey,
              uiStyle: widget.uiStyle,
              title: 'Nilpotents',
              count: widget.analysis.nilpotentsCount,
              isExpanded: _nilpotentsExpanded,
              onExpansionChanged: (val) =>
                  setState(() => _nilpotentsExpanded = val),
              child: _DataChipGrid(items: widget.analysis.nilpotents),
            ),
          if (widget.analysis.inverses.isNotEmpty)
            _ExpandableDataSection(
              key: _inversesKey,
              uiStyle: widget.uiStyle,
              title: 'Inverses',
              count: widget.analysis.inverses.length.toString(),
              isExpanded: _inversesExpanded,
              onExpansionChanged: (val) =>
                  setState(() => _inversesExpanded = val),
              child: _InverseTable(
                  uiStyle: widget.uiStyle, inverses: widget.analysis.inverses),
            ),
          if (widget.analysis.elementOrders.isNotEmpty)
            _ExpandableDataSection(
              key: _elementOrdersKey,
              uiStyle: widget.uiStyle,
              title: 'Element Orders',
              count: widget.analysis.elementOrders.length.toString(),
              isExpanded: _elementOrdersExpanded,
              onExpansionChanged: (val) =>
                  setState(() => _elementOrdersExpanded = val),
              child: _ElementOrderTable(
                  uiStyle: widget.uiStyle,
                  orders: widget.analysis.elementOrders),
            ),
          if (widget.analysis.cayleyTable != null)
            _ExpandableDataSection(
              key: const ValueKey('cayley_table'),
              uiStyle: widget.uiStyle,
              title: 'Cayley Table',
              count: '1',
              isExpanded: true,
              onExpansionChanged: (_) {},
              child: CayleyTableView(
                uiStyle: widget.uiStyle,
                cayleyTable: widget.analysis.cayleyTable!,
                identity: widget.analysis.identity,
                inverses: widget.analysis.inverses,
              ),
            ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final UiStyle uiStyle;
  final String title;
  final String value;
  final VoidCallback? onTap;

  const _MetricCard({
    required this.uiStyle,
    required this.title,
    required this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: SharedSurface(
        uiStyle: uiStyle,
        glassRole: GlassSurfaceRole.card,
        frosted: true,
        borderRadius: BorderRadius.circular(16),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (onTap != null)
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: onTap != null
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpandableDataSection extends StatelessWidget {
  final UiStyle uiStyle;
  final String title;
  final String count;
  final bool isExpanded;
  final ValueChanged<bool> onExpansionChanged;
  final Widget child;

  const _ExpandableDataSection({
    super.key,
    required this.uiStyle,
    required this.title,
    required this.count,
    required this.isExpanded,
    required this.onExpansionChanged,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      color: Colors.transparent,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: ExpansionTile(
        title: Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text('$count items'),
        initiallyExpanded: isExpanded,
        onExpansionChanged: onExpansionChanged,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        collapsedShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        childrenPadding: const EdgeInsets.all(16),
        children: [
          child,
        ],
      ),
    );
  }
}

class _DataChipGrid extends StatelessWidget {
  final List<String> items;

  const _DataChipGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: items
            .map((item) => Chip(
                  label: Text(item),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ))
            .toList(),
      ),
    );
  }
}

class _InverseTable extends StatelessWidget {
  final UiStyle uiStyle;
  final List<InversePair> inverses;

  const _InverseTable({
    required this.uiStyle,
    required this.inverses,
  });

  @override
  Widget build(BuildContext context) {
    // Determine the height based on items to avoid infinite height in Column
    final height = (inverses.length * 48.0) + 56.0; // Header + Row heights
    final boundedHeight = height > 400 ? 400.0 : height;

    return SizedBox(
      height: boundedHeight,
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Theme.of(context).dividerColor),
              ),
            ),
            child: const Row(
              children: [
                Expanded(
                  child: Text(
                    'Element (a)',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Inverse (a⁻¹)',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: inverses.length,
              itemBuilder: (context, index) {
                final pair = inverses[index];
                return Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(pair.element),
                      ),
                      Expanded(
                        child: Text(pair.inverse),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ElementOrderTable extends StatelessWidget {
  final UiStyle uiStyle;
  final List<ElementOrderPair> orders;

  const _ElementOrderTable({
    required this.uiStyle,
    required this.orders,
  });

  @override
  Widget build(BuildContext context) {
    final height = (orders.length * 48.0) + 56.0;
    final boundedHeight = height > 400 ? 400.0 : height;

    return SizedBox(
      height: boundedHeight,
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Theme.of(context).dividerColor),
              ),
            ),
            child: const Row(
              children: [
                Expanded(
                  child: Text(
                    'Element (a)',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Order (k)',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: orders.length,
              itemBuilder: (context, index) {
                final pair = orders[index];
                return Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(pair.element),
                      ),
                      Expanded(
                        child: Text(pair.order),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
