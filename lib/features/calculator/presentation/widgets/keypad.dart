import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:calc_flut_rs/app/theme/ui_style.dart';
import 'package:calc_flut_rs/features/calculator/presentation/providers/calculator_provider.dart';
import 'package:calc_flut_rs/features/calculator/presentation/providers/calculator_state.dart';
import 'package:calc_flut_rs/features/calculator/presentation/widgets/animated_equals_button.dart';
import 'package:calc_flut_rs/features/calculator/presentation/widgets/calc_key_spec.dart';
import 'package:calc_flut_rs/features/calculator/presentation/widgets/calculator_chip_row.dart';
import 'package:calc_flut_rs/features/settings/presentation/providers/theme_provider.dart';
import 'package:calc_flut_rs/shared/layouts/breakpoints.dart';
import 'package:calc_flut_rs/shared/widgets/app_button.dart';

/// The interactive keypad for the calculator.
///
/// Adapts dynamically to show scientific functions, trigonometric options, logs,
/// and memory operations based on the current state.
///
/// The layout is a function of the rows in [calc_key_spec], not a literal
/// arrangement of widgets, so a key is added or moved in one list rather than in
/// a nested widget tree.
///
/// Every key here has exactly one action, and it is the action its label names.
/// The MOD key in particular used to carry an undocumented long-press that
/// assigned `2` to `selectedTabProvider`; since this screen only ever branches on
/// `== 0` versus anything-else, that produced the Function Evaluator — the same
/// result as tapping the visible segmented control directly above the keypad. A
/// hidden gesture on a key labelled `MOD` that opens an unrelated mode is worse
/// than no gesture at all, so it is gone rather than relabelled.
class Keypad extends ConsumerWidget {
  const Keypad({super.key});

  /// Smallest height a key may shrink to on a short screen.
  ///
  /// [AppCalcButton] pads each key, so the smallest row is this plus its
  /// vertical padding. The number exists so the row heights below are expressed
  /// as proportions of the space that is actually available.
  static const double minKeyHeight = 48.0;

  /// Number of rows that hold digits and operators, and so are held to
  /// [minKeyHeight]: the bracket row, three digit rows, the `0 . MOD +` row and
  /// the `AC ANS ⌫ =` row.
  static const int _primaryRowCount = 6;

  /// Flex weight of the bracket row. Lower than a digit row's, as it always
  /// was: it holds two brackets and two rarely-used operators.
  static const int _functionRowFlex = 60;

  /// Flex weight of a digit or action row.
  static const int _digitRowFlex = 72;

  /// The scientific row's own natural height.
  ///
  /// All or nothing: a scientific row squeezed to 20dp would show keys with no
  /// room to press, which is worse than not showing it.
  static const double _naturalSciRowHeight = 60.0;

  /// Height for a primary row of [flex] weight, given the space available.
  ///
  /// The rows are provisioned at [minKeyHeight] first and only the surplus is
  /// shared out, by the same weights the layout has always used. Distributing
  /// the whole height by weight instead — which is what this did — cannot
  /// express a floor: the bracket row carries the smallest weight, so it ends
  /// up the shortest key on the screen, at 44dp on a 450dp keypad.
  static double _primaryRowHeight({
    required double forKeyRows,
    required int flex,
  }) {
    final floor = minKeyHeight + AppCalcButton.verticalPadding * 2;
    final totalFlex = _functionRowFlex + _digitRowFlex * (_primaryRowCount - 1);

    if (forKeyRows < floor * _primaryRowCount) {
      // Genuinely not enough room even for the floor. Share what there is
      // rather than overflowing; the caller has already guaranteed the
      // calculator's `keypadMinHeight`, so this is a last resort.
      return forKeyRows * (flex / totalFlex);
    }
    return floor + (forKeyRows - floor * _primaryRowCount) * (flex / totalFlex);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(calculatorProvider);
    final uiStyle = ref.watch(uiStyleProvider);

    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 0, 6, 4),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxHeight = constraints.maxHeight.isFinite
                ? constraints.maxHeight
                : 400.0;
            final panelHeight = state.expandedPanel == ExpandedPanel.none
                ? 0.0
                : 40.0;

            final forKeyRows =
                (maxHeight - CalculatorChipRow.totalHeight - panelHeight).clamp(
                  0.0,
                  double.infinity,
                );

            // A window measured at zero — the shell builds sections inside an
            // IndexedStack, so the first frame can still be measuring. Render
            // nothing rather than lay keys out into no space.
            if (forKeyRows <= 0) return const SizedBox.shrink();

            // The scientific utility row is a convenience layer over functions
            // also reachable by typing, so it is the one thing that yields when
            // space is short: it appears at its natural height only when the
            // primary rows can be provisioned without it.
            final primaryFloor =
                (minKeyHeight + AppCalcButton.verticalPadding * 2) *
                _primaryRowCount;
            final surplus = forKeyRows - primaryFloor;
            final sciRowHeight = surplus >= _naturalSciRowHeight
                ? _naturalSciRowHeight
                : 0.0;

            return Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                CalculatorChipRow(
                  isSci: state.isScientificMode,
                  expanded: state.expandedPanel,
                  ref: ref,
                  uiStyle: uiStyle,
                ),
                AnimatedSize(
                  duration: context.motion(const Duration(milliseconds: 200)),
                  curve: Curves.easeInOut,
                  alignment: Alignment.topCenter,
                  child: _KeyRow(
                    row: expandedPanelRow(ref, state, state.expandedPanel),
                    uiStyle: uiStyle,
                    height: panelHeight,
                  ),
                ),
                ClipRect(
                  child: AnimatedContainer(
                    duration: context.motion(const Duration(milliseconds: 250)),
                    curve: Curves.easeInOut,
                    height: state.isScientificMode ? sciRowHeight : 0.0,
                    child: _KeyRow(
                      row: scientificUtilityRow(ref),
                      uiStyle: uiStyle,
                    ),
                  ),
                ),
                SizedBox(
                  height: _primaryRowHeight(
                    forKeyRows: forKeyRows - sciRowHeight,
                    flex: _functionRowFlex,
                  ),
                  child: _KeyRow(row: functionKeyRow(ref), uiStyle: uiStyle),
                ),
                for (final row in [
                  digitRow(ref, '7', '8', '9', '\u00f7'),
                  digitRow(ref, '4', '5', '6', '\u00d7'),
                  digitRow(ref, '1', '2', '3', '\u2212'),
                  zeroRow(ref),
                ])
                  SizedBox(
                    height: _primaryRowHeight(
                      forKeyRows: forKeyRows - sciRowHeight,
                      flex: _digitRowFlex,
                    ),
                    child: _KeyRow(row: row, uiStyle: uiStyle),
                  ),
                SizedBox(
                  height: _primaryRowHeight(
                    forKeyRows: forKeyRows - sciRowHeight,
                    flex: _digitRowFlex,
                  ),
                  child: _KeyRow(row: actionRow(ref), uiStyle: uiStyle),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Renders one row of [CalcKeySpec]s, each taking an equal share of the width.
class _KeyRow extends StatelessWidget {
  final CalcKeyRow row;
  final UiStyle uiStyle;

  /// Fixed height, or `null` to fill whatever the parent offers.
  final double? height;

  const _KeyRow({required this.row, required this.uiStyle, this.height});

  @override
  Widget build(BuildContext context) {
    if (row.isEmpty) return const SizedBox.shrink();

    Widget content = Row(
      children: [
        for (final spec in row)
          Expanded(
            child: _Key(spec: spec, uiStyle: uiStyle),
          ),
      ],
    );
    if (height != null) content = SizedBox(height: height, child: content);
    return content;
  }
}

/// One key, in whichever of the two button styles it needs.
class _Key extends StatelessWidget {
  final CalcKeySpec spec;
  final UiStyle uiStyle;

  const _Key({required this.spec, required this.uiStyle});

  @override
  Widget build(BuildContext context) {
    if (spec.isEquals) {
      return AnimatedEqualsButton(
        onEvaluate: spec.onEvaluate ?? () async => spec.onPressed(),
      );
    }

    Widget button = AppCalcButton(
      text: spec.label,
      type: spec.type,
      onPressed: spec.onPressed,
      isActive: spec.isActive,
      uiStyle: uiStyle,
    );

    if (spec.tooltip != null) {
      button = Tooltip(
        message: spec.tooltip!,
        waitDuration: const Duration(milliseconds: 400),
        child: button,
      );
    }
    return button;
  }
}
