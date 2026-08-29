import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:calc_flut_rs/app/theme/ui_style.dart';
import 'package:calc_flut_rs/features/calculator/presentation/providers/calculator_provider.dart';
import 'package:calc_flut_rs/features/calculator/presentation/providers/calculator_state.dart';
import 'package:calc_flut_rs/shared/widgets/app_button.dart';
import 'package:calc_flut_rs/features/calculator/presentation/widgets/animated_equals_button.dart';
import 'package:calc_flut_rs/features/settings/presentation/providers/theme_provider.dart';
import 'package:calc_flut_rs/features/calculator/presentation/screens/calculator_screen.dart';

/// The interactive keypad for the calculator.
///
/// Adapts dynamically to show scientific functions, trigonometric options, logs,
/// and memory operations based on the current state.
class Keypad extends ConsumerWidget {
  const Keypad({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(calculatorProvider);
    final uiStyle = ref.watch(uiStyleProvider);
    final isSci = state.isScientificMode;
    final expanded = state.expandedPanel;

    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 0, 6, 4),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double maxHeight = constraints.maxHeight.isFinite
                ? constraints.maxHeight
                : 400.0;
            final fixedHeight =
                48.0 + (expanded != ExpandedPanel.none ? 40.0 : 0.0);
            final availableHeight = maxHeight - fixedHeight;
            final sciRowHeight = (availableHeight * (60.0 / 480.0)).clamp(
              0.0,
              double.infinity,
            );

            return Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // === Dropdown chip row: [▾] [Trig ∨] [Log ∨] [Mem ∨] ===
                _DropdownChipRow(
                  isSci: isSci,
                  expanded: state.expandedPanel,
                  ref: ref,
                  uiStyle: uiStyle,
                ),

                // === Expanded panel content (animated) ===
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  alignment: Alignment.topCenter,
                  child: _buildExpandedContent(ref, state, expanded, uiStyle),
                ),

                // === Scientific utility row: √ ^ ! π ===
                ClipRect(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    height: isSci ? sciRowHeight : 0.0,
                    child: SingleChildScrollView(
                      physics: const NeverScrollableScrollPhysics(),
                      child: SizedBox(
                        height: sciRowHeight,
                        child: Row(
                          children: [
                            _btn(ref, '√', ButtonType.scientific, () {
                              ref
                                  .read(calculatorProvider.notifier)
                                  .appendFunctionTemplate('sqrt');
                              return true;
                            }, uiStyle: uiStyle),
                            _btn(
                              ref,
                              '^',
                              ButtonType.scientific,
                              () => ref
                                  .read(calculatorProvider.notifier)
                                  .append('^'),
                              uiStyle: uiStyle,
                            ),
                            _btn(
                              ref,
                              '!',
                              ButtonType.scientific,
                              () => ref
                                  .read(calculatorProvider.notifier)
                                  .append('!'),
                              uiStyle: uiStyle,
                            ),
                            _btn(
                              ref,
                              'π',
                              ButtonType.scientific,
                              () => ref
                                  .read(calculatorProvider.notifier)
                                  .append('π'),
                              uiStyle: uiStyle,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // === ( ) % / ===
                Expanded(
                  flex: 60,
                  child: Row(
                    children: [
                      _btn(
                        ref,
                        '(',
                        ButtonType.action,
                        () => ref.read(calculatorProvider.notifier).append('('),
                        uiStyle: uiStyle,
                      ),
                      _btn(
                        ref,
                        ')',
                        ButtonType.action,
                        () => ref.read(calculatorProvider.notifier).append(')'),
                        uiStyle: uiStyle,
                      ),
                      _btn(
                        ref,
                        '%',
                        ButtonType.action,
                        () => ref.read(calculatorProvider.notifier).append('%'),
                        tooltip: 'Percentage',
                        uiStyle: uiStyle,
                      ),
                      _btn(
                        ref,
                        '/',
                        ButtonType.action,
                        () => ref.read(calculatorProvider.notifier).append('/'),
                        tooltip: 'Fraction',
                        uiStyle: uiStyle,
                      ),
                    ],
                  ),
                ),

                // === Number grid + operators ===
                // 7 8 9 ÷
                Expanded(
                  flex: 72,
                  child: Row(
                    children: [
                      _btn(
                        ref,
                        '7',
                        ButtonType.number,
                        () => ref.read(calculatorProvider.notifier).append('7'),
                        uiStyle: uiStyle,
                      ),
                      _btn(
                        ref,
                        '8',
                        ButtonType.number,
                        () => ref.read(calculatorProvider.notifier).append('8'),
                        uiStyle: uiStyle,
                      ),
                      _btn(
                        ref,
                        '9',
                        ButtonType.number,
                        () => ref.read(calculatorProvider.notifier).append('9'),
                        uiStyle: uiStyle,
                      ),
                      _btn(
                        ref,
                        '÷',
                        ButtonType.operator,
                        () => ref.read(calculatorProvider.notifier).append('÷'),
                        uiStyle: uiStyle,
                      ),
                    ],
                  ),
                ),
                // 4 5 6 ×
                Expanded(
                  flex: 72,
                  child: Row(
                    children: [
                      _btn(
                        ref,
                        '4',
                        ButtonType.number,
                        () => ref.read(calculatorProvider.notifier).append('4'),
                        uiStyle: uiStyle,
                      ),
                      _btn(
                        ref,
                        '5',
                        ButtonType.number,
                        () => ref.read(calculatorProvider.notifier).append('5'),
                        uiStyle: uiStyle,
                      ),
                      _btn(
                        ref,
                        '6',
                        ButtonType.number,
                        () => ref.read(calculatorProvider.notifier).append('6'),
                        uiStyle: uiStyle,
                      ),
                      _btn(
                        ref,
                        '×',
                        ButtonType.operator,
                        () => ref.read(calculatorProvider.notifier).append('×'),
                        uiStyle: uiStyle,
                      ),
                    ],
                  ),
                ),
                // 1 2 3 −
                Expanded(
                  flex: 72,
                  child: Row(
                    children: [
                      _btn(
                        ref,
                        '1',
                        ButtonType.number,
                        () => ref.read(calculatorProvider.notifier).append('1'),
                        uiStyle: uiStyle,
                      ),
                      _btn(
                        ref,
                        '2',
                        ButtonType.number,
                        () => ref.read(calculatorProvider.notifier).append('2'),
                        uiStyle: uiStyle,
                      ),
                      _btn(
                        ref,
                        '3',
                        ButtonType.number,
                        () => ref.read(calculatorProvider.notifier).append('3'),
                        uiStyle: uiStyle,
                      ),
                      _btn(
                        ref,
                        '−',
                        ButtonType.operator,
                        () => ref.read(calculatorProvider.notifier).append('−'),
                        uiStyle: uiStyle,
                      ),
                    ],
                  ),
                ),
                // 0 . mod +
                Expanded(
                  flex: 72,
                  child: Row(
                    children: [
                      _btn(
                        ref,
                        '0',
                        ButtonType.number,
                        () => ref.read(calculatorProvider.notifier).append('0'),
                        uiStyle: uiStyle,
                      ),
                      _btn(
                        ref,
                        '.',
                        ButtonType.number,
                        () => ref.read(calculatorProvider.notifier).append('.'),
                        uiStyle: uiStyle,
                      ),
                      _btn(
                        ref,
                        'MOD',
                        ButtonType.scientific,
                        () =>
                            ref.read(calculatorProvider.notifier).append('mod'),
                        tooltip: 'Remainder after division',
                        uiStyle: uiStyle,
                        onLongPress: () {
                          ref.read(selectedTabProvider.notifier).update(2);
                        },
                      ),
                      _btn(
                        ref,
                        '+',
                        ButtonType.operator,
                        () => ref.read(calculatorProvider.notifier).append('+'),
                        uiStyle: uiStyle,
                      ),
                    ],
                  ),
                ),
                // AC ANS ⌫ =
                Expanded(
                  flex: 72,
                  child: Row(
                    children: [
                      _btn(ref, 'AC', ButtonType.clear, () {
                        ref.read(calculatorProvider.notifier).clear();
                        return true;
                      }, uiStyle: uiStyle),
                      _btn(
                        ref,
                        'ANS',
                        ButtonType.action,
                        () =>
                            ref.read(calculatorProvider.notifier).append('Ans'),
                        tooltip: 'Last Answer',
                        uiStyle: uiStyle,
                      ),
                      _buildBackspaceButton(ref, uiStyle),
                      Expanded(
                        child: AnimatedEqualsButton(
                          onEvaluate: () =>
                              ref.read(calculatorProvider.notifier).evaluate(),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildBackspaceButton(WidgetRef ref, UiStyle uiStyle) {
    return Expanded(
      child: AppCalcButton(
        text: '',
        icon: const Icon(Icons.backspace_outlined, size: 20),
        type: ButtonType.backspace,
        onPressed: () {
          ref.read(calculatorProvider.notifier).delete();
          return true;
        },
        uiStyle: uiStyle,
      ),
    );
  }

  Widget _buildExpandedContent(
    WidgetRef ref,
    CalculatorState state,
    ExpandedPanel expanded,
    UiStyle uiStyle,
  ) {
    switch (expanded) {
      case ExpandedPanel.trig:
        return SizedBox(
          height: 40,
          child: Row(
            children: [
              _btn(
                ref,
                state.isDegreeMode ? 'Deg' : 'Rad',
                ButtonType.scientific,
                () {
                  ref.read(calculatorProvider.notifier).toggleDegreeMode();
                  return true;
                },
                isActive: state.isDegreeMode,
                uiStyle: uiStyle,
              ),
              _btn(
                ref,
                state.isInvMode
                    ? (state.isHypMode ? 'asinh' : 'asin')
                    : (state.isHypMode ? 'sinh' : 'sin'),
                ButtonType.scientific,
                () {
                  final funcName = state.isInvMode
                      ? (state.isHypMode ? 'asinh' : 'asin')
                      : (state.isHypMode ? 'sinh' : 'sin');
                  ref
                      .read(calculatorProvider.notifier)
                      .appendFunctionTemplate(funcName);
                  return true;
                },
                uiStyle: uiStyle,
              ),
              _btn(
                ref,
                state.isInvMode
                    ? (state.isHypMode ? 'acosh' : 'acos')
                    : (state.isHypMode ? 'cosh' : 'cos'),
                ButtonType.scientific,
                () {
                  final funcName = state.isInvMode
                      ? (state.isHypMode ? 'acosh' : 'acos')
                      : (state.isHypMode ? 'cosh' : 'cos');
                  ref
                      .read(calculatorProvider.notifier)
                      .appendFunctionTemplate(funcName);
                  return true;
                },
                uiStyle: uiStyle,
              ),
              _btn(
                ref,
                state.isInvMode
                    ? (state.isHypMode ? 'atanh' : 'atan')
                    : (state.isHypMode ? 'tanh' : 'tan'),
                ButtonType.scientific,
                () {
                  final funcName = state.isInvMode
                      ? (state.isHypMode ? 'atanh' : 'atan')
                      : (state.isHypMode ? 'tanh' : 'tan');
                  ref
                      .read(calculatorProvider.notifier)
                      .appendFunctionTemplate(funcName);
                  return true;
                },
                uiStyle: uiStyle,
              ),
              _btn(
                ref,
                'Inv',
                ButtonType.scientific,
                () {
                  ref.read(calculatorProvider.notifier).toggleInvMode();
                  return true;
                },
                isActive: state.isInvMode,
                uiStyle: uiStyle,
              ),
            ],
          ),
        );
      case ExpandedPanel.log:
        return SizedBox(
          height: 40,
          child: Row(
            children: [
              _btn(ref, 'log₁₀', ButtonType.scientific, () {
                ref
                    .read(calculatorProvider.notifier)
                    .appendFunctionTemplate('log');
                return true;
              }, uiStyle: uiStyle),
              _btn(ref, 'ln', ButtonType.scientific, () {
                ref
                    .read(calculatorProvider.notifier)
                    .appendFunctionTemplate('ln');
                return true;
              }, uiStyle: uiStyle),
              _btn(ref, 'logₙ', ButtonType.scientific, () {
                ref.read(calculatorProvider.notifier).appendLogTemplate();
                return true;
              }, uiStyle: uiStyle),
              _btn(
                ref,
                'e',
                ButtonType.scientific,
                () => ref.read(calculatorProvider.notifier).append('e'),
                uiStyle: uiStyle,
              ),
            ],
          ),
        );
      case ExpandedPanel.memory:
        return SizedBox(
          height: 40,
          child: Row(
            children: [
              _btn(ref, 'MC', ButtonType.scientific, () {
                ref.read(calculatorProvider.notifier).memoryClear();
                return true;
              }, uiStyle: uiStyle),
              _btn(
                ref,
                'MR',
                ButtonType.scientific,
                () => ref.read(calculatorProvider.notifier).memoryRecall(),
                uiStyle: uiStyle,
              ),
              _btn(
                ref,
                'M+',
                ButtonType.scientific,
                () => ref.read(calculatorProvider.notifier).memoryAdd(),
                uiStyle: uiStyle,
              ),
              _btn(
                ref,
                'M−',
                ButtonType.scientific,
                () => ref.read(calculatorProvider.notifier).memorySubtract(),
                uiStyle: uiStyle,
              ),
              _btn(
                ref,
                'MS',
                ButtonType.scientific,
                () => ref.read(calculatorProvider.notifier).memoryStore(),
                uiStyle: uiStyle,
              ),
            ],
          ),
        );
      case ExpandedPanel.none:
        return const SizedBox.shrink();
    }
  }

  Widget _btn(
    WidgetRef ref,
    String text,
    ButtonType type,
    bool Function() onPressed, {
    bool isActive = false,
    String? tooltip,
    required UiStyle uiStyle,
    VoidCallback? onLongPress,
  }) {
    Widget btn = AppCalcButton(
      text: text,
      type: type,
      onPressed: onPressed,
      onLongPress: onLongPress,
      isActive: isActive,
      uiStyle: uiStyle,
    );
    if (tooltip != null) {
      btn = Tooltip(
        message: tooltip,
        waitDuration: const Duration(milliseconds: 400),
        child: btn,
      );
    }
    return Expanded(child: btn);
  }
}

/// A row of interactive chips used to toggle scientific mode and open
/// secondary panels (Trig, Log, Mem).
class _DropdownChipRow extends StatelessWidget {
  final bool isSci;
  final ExpandedPanel expanded;
  final WidgetRef ref;
  final UiStyle uiStyle;

  const _DropdownChipRow({
    required this.isSci,
    required this.expanded,
    required this.ref,
    required this.uiStyle,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
      child: SizedBox(
        height: 48,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          transitionBuilder: (child, animation) {
            return FadeTransition(opacity: animation, child: child);
          },
          child: Row(
            key: ValueKey(isSci),
            children: [
              _buildChip(
                context,
                label: 'Sci',
                bgColor: isSci
                    ? colorScheme.secondaryContainer
                    : colorScheme.surfaceContainerHigh,
                fgColor: isSci
                    ? colorScheme.onSecondaryContainer
                    : colorScheme.onSurfaceVariant,
                onTap: () => ref
                    .read(calculatorProvider.notifier)
                    .toggleScientificMode(),
                isExpanded: isSci,
              ),

              if (isSci) ...[
                const SizedBox(width: 6),
                Expanded(
                  child: _buildChip(
                    context,
                    label: 'Trig',
                    bgColor: colorScheme.tertiaryContainer,
                    fgColor: colorScheme.onTertiaryContainer,
                    onTap: () => ref
                        .read(calculatorProvider.notifier)
                        .togglePanel(ExpandedPanel.trig),
                    isExpanded: expanded == ExpandedPanel.trig,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _buildChip(
                    context,
                    label: 'Log',
                    bgColor: colorScheme.secondaryContainer,
                    fgColor: colorScheme.onSecondaryContainer,
                    onTap: () => ref
                        .read(calculatorProvider.notifier)
                        .togglePanel(ExpandedPanel.log),
                    isExpanded: expanded == ExpandedPanel.log,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _buildChip(
                    context,
                    label: 'Mem',
                    bgColor: colorScheme.primaryContainer,
                    fgColor: colorScheme.onPrimaryContainer,
                    onTap: () => ref
                        .read(calculatorProvider.notifier)
                        .togglePanel(ExpandedPanel.memory),
                    isExpanded: expanded == ExpandedPanel.memory,
                  ),
                ),
              ] else
                const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChip(
    BuildContext context, {
    required String label,
    required Color bgColor,
    required Color fgColor,
    required VoidCallback onTap,
    required bool isExpanded,
  }) {
    if (uiStyle == UiStyle.liquidGlass) {
      // Lightweight frosted chip — no shader
      return Material(
        color: bgColor.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: fgColor,
                    ),
                  ),
                  const SizedBox(width: 2),
                  AnimatedRotation(
                    duration: const Duration(milliseconds: 200),
                    turns: isExpanded ? 0.5 : 0.0,
                    child: Icon(Icons.expand_more, size: 18, color: fgColor),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: fgColor,
                  ),
                ),
                const SizedBox(width: 2),
                AnimatedRotation(
                  duration: const Duration(milliseconds: 200),
                  turns: isExpanded ? 0.5 : 0.0,
                  child: Icon(Icons.expand_more, size: 18, color: fgColor),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
