import 'package:flutter/material.dart';

/// A single tool that records history.
///
/// One value per *tool*, not per section. The Calculator section's two
/// segmented modes are separate tools and get separate filters, and so is each
/// of the five independent tools behind the Symbolic Math hub — a Calculus entry
/// is not the same thing as a Matrices entry, and lumping them into one
/// `symbolic` bucket made the filter useless exactly as the section grew.
///
/// Tools are grouped for *display* by [group], so the filter row stays short
/// even as tools are added. The grouping is never the unit of storage: what
/// lands in history, and what a tool can filter down to, is always a
/// [HistoryCategory].
///
/// The enum member name is the string written to the Rust history store, so
/// renaming one orphans its existing entries. [HistoryGroup.legacyCategoryNames]
/// covers the one category this model replaced.
enum HistoryCategory {
  calculator(
    'Calculator',
    Icons.calculate,
    HistoryGroup.calculator,
    'Basic calculator history',
  ),
  functionEvaluator(
    'Fn Evaluator',
    Icons.functions,
    HistoryGroup.calculator,
    'Function evaluator history',
  ),
  modularArithmetic(
    'Modular Math',
    Icons.architecture,
    HistoryGroup.modularArithmetic,
    'Modular arithmetic history',
  ),
  algebra('Algebra', Icons.functions, HistoryGroup.symbolic, 'Algebra history'),
  equationSolver(
    'Equation Solver',
    Icons.balance,
    HistoryGroup.symbolic,
    'Equation solver history',
  ),
  calculus(
    'Calculus',
    Icons.show_chart,
    HistoryGroup.symbolic,
    'Calculus history',
  ),
  matrices('Matrices', Icons.grid_on, HistoryGroup.symbolic, 'Matrix history'),
  numberTheory(
    'Number Theory',
    Icons.tag,
    HistoryGroup.symbolic,
    'Number theory history',
  );

  /// Short name shown on the tool-level filter chips.
  final String label;

  /// Icon shown beside the tool's label.
  final IconData icon;

  /// The section-style group this tool belongs to.
  final HistoryGroup group;

  /// Longer explanation, shown as the chip's tooltip and its semantic label.
  final String tooltip;

  const HistoryCategory(this.label, this.icon, this.group, this.tooltip);

  /// The categories this tool has stored under, including any name it used
  /// before the category was split.
  Set<String> get storedNames => {name, ...group.legacyCategoryNames};
}

/// A group of related tools, used for the history filter's primary row.
///
/// The groups mirror the app's own top-level sections that contain tools, so
/// the filter reads as navigation rather than as an unrelated taxonomy. A group
/// that holds a single tool collapses to that tool: there is nothing for a
/// second row to disambiguate.
enum HistoryGroup {
  calculator('Calculator', Icons.calculate_outlined, 'Basic arithmetic tools'),
  modularArithmetic(
    'Modular Math',
    Icons.architecture,
    'Modular arithmetic and ring analysis',
  ),
  symbolic('Symbolic Math', Icons.auto_fix_high, 'Computer algebra tools');

  /// Name shown on the group-level filter chips.
  final String label;

  /// Icon shown beside the group's label.
  final IconData icon;

  /// Longer explanation, shown as the chip's tooltip.
  final String tooltip;

  const HistoryGroup(this.label, this.icon, this.tooltip);

  /// Categories stored under names this model no longer writes.
  ///
  /// Every tool in the symbolic group was previously written as a single
  /// `symbolic` category, so entries recorded before the split are still on
  /// disk. Reading them here means the split does not silently orphan anyone's
  /// history — they keep showing up under Symbolic Math, and
  /// `restoreSymbolicSnapshot` still opens them, because it dispatches on the
  /// snapshot's own shape.
  Set<String> get legacyCategoryNames =>
      this == HistoryGroup.symbolic ? const {'symbolic'} : const {};

  /// The tools in this group, in display order.
  List<HistoryCategory> get categories => HistoryCategory.values
      .where((category) => category.group == this)
      .toList();

  /// Whether this group needs a second, tool-level filter row.
  ///
  /// A one-tool group is not ambiguous, so showing a row of one chip would be
  /// pure chrome.
  bool get hasMultipleTools => categories.length > 1;
}

/// The tool-level filter currently in effect, or nothing for a whole group.
extension HistoryCategoryFilter on HistoryCategory {
  bool matches(String storedCategory) => storedNames.contains(storedCategory);
}

/// Resolves which tools a given selection covers.
///
/// [group] is `null` for the "All" view, which is the default: one
/// recency-sorted feed across every tool, so an empty screen can answer
/// "have I computed anything at all in this app?" rather than only "have I
/// computed anything *in this category*?".
Set<HistoryCategory> historyCategoriesFor({
  HistoryGroup? group,
  HistoryCategory? category,
}) {
  if (category != null) return {category};
  if (group != null) return group.categories.toSet();
  return HistoryCategory.values.toSet();
}

/// Whether a stored history entry belongs to the current selection.
///
/// Both selections omitted means the "All" view, which is why neither is
/// required.
///
/// "All" matches *everything*, including a category this build does not
/// recognise. Matching only the known tools would hide an entry written by a
/// version of the app that had a tool this one no longer has — and a hidden
/// entry cannot be read or deleted, so it is gone as far as the user is
/// concerned while still occupying the file. A group or tool filter excludes
/// them, because they are not part of that group by any reading.
bool historyEntryMatches(
  String storedCategory, {
  HistoryGroup? group,
  HistoryCategory? category,
}) {
  if (category != null) return category.matches(storedCategory);
  if (group != null) {
    return group.categories.any((tool) => tool.matches(storedCategory));
  }
  return true;
}

/// A human name for the current selection, for the empty state and the clear
/// dialog. "All tools" rather than a bare "All" when nothing is selected.
String historySelectionLabel({HistoryGroup? group, HistoryCategory? category}) {
  if (category != null) return category.label;
  if (group != null) return group.label;
  return 'All tools';
}
