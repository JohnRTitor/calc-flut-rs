import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:calc_flut_rs/features/calculator/presentation/providers/calculator_provider.dart';
import 'package:calc_flut_rs/features/calculator/presentation/providers/calculator_state.dart';
import 'package:calc_flut_rs/shared/widgets/app_button.dart';

/// One key on the calculator keypad.
///
/// The keypad used to be the layout written out literally, row by row, as
/// nested `Row`/`Expanded` pairs — about thirty near-identical blocks, each
/// repeating the same builder call. Reordering a key, or giving it a
/// conditional label, meant editing widget tree rather than data, which is how a
/// key came to carry a long-press nobody had tested.
///
/// A key is now a value. The layout is a function of the rows, so a change to
/// the layout happens in one place and a change to a key happens in one list.
class CalcKeySpec {
  /// The key's caption. Also the label its tooltip names, when it has one.
  final String label;

  /// Decides the key's colour and type size.
  final ButtonType type;

  /// The key's action. Returns `false` to signal failure, which is what makes
  /// the key shake and vibrate.
  final bool Function() onPressed;

  /// The key's asynchronous action, for the one key that has one.
  ///
  /// Only [isEquals] uses this: evaluation is a bridge call that reports its
  /// own success, so it cannot be expressed as [onPressed]. Keeping it as a
  /// separate, named field is honest about that rather than pretending the
  /// equals key is an ordinary insert.
  final Future<bool> Function()? onEvaluate;

  /// Drawn as a pressed/latched style, for a mode currently in effect.
  final bool isActive;

  /// Long-press explanation. `null` for a key with no secondary behaviour.
  final String? tooltip;

  /// Whether this slot holds the equals key.
  ///
  /// Named rather than smuggled in as a widget because equals is the one key
  /// that is not an [AppCalcButton]: it has its own animated failure feedback,
  /// and the keypad's height budget depends on it. Everything else renders the
  /// same way, which is the point of the model.
  final bool isEquals;

  const CalcKeySpec(
    this.label,
    this.type,
    this.onPressed, {
    this.isActive = false,
    this.tooltip,
    this.isEquals = false,
    this.onEvaluate,
  });
}

/// A row of keys, all of which share the row's share of the height.
typedef CalcKeyRow = List<CalcKeySpec>;

/// Inserts [token] into the expression. Always a success: typing cannot fail.
bool _append(WidgetRef ref, String token) {
  ref.read(calculatorProvider.notifier).append(token);
  return true;
}

/// Inserts a function template such as `sqrt(`. Always a success.
bool _appendFn(WidgetRef ref, String name) {
  ref.read(calculatorProvider.notifier).appendFunctionTemplate(name);
  return true;
}

/// The trigonometric name a key inserts, given the current INV and HYP modes.
///
/// HYP appends the `h` (`sin` becomes `sinh`) and INV prefixes the `a`
/// (`sinh` becomes `asinh`). The two affixes go on opposite ends, so this
/// cannot be written as one prefix or one suffix.
String trigKeyName(String base, {required bool inv, required bool hyp}) {
  final hyperbolised = hyp ? '${base}h' : base;
  return inv ? 'a$hyperbolised' : hyperbolised;
}

/// The scientific utility row: `√ ^ ! π`.
///
/// Collapses to zero height unless scientific mode is on, which is the
/// keypad's one piece of conditional layout.
CalcKeyRow scientificUtilityRow(WidgetRef ref) => [
  CalcKeySpec('√', ButtonType.scientific, () {
    _appendFn(ref, 'sqrt');
    return true;
  }),
  CalcKeySpec('^', ButtonType.scientific, () => _append(ref, '^')),
  CalcKeySpec('!', ButtonType.scientific, () => _append(ref, '!')),
  CalcKeySpec('π', ButtonType.scientific, () => _append(ref, 'π')),
];

/// The bracket and arithmetic-operator row: `( ) % /`.
CalcKeyRow functionKeyRow(WidgetRef ref) => [
  CalcKeySpec('(', ButtonType.action, () => _append(ref, '(')),
  CalcKeySpec(')', ButtonType.action, () => _append(ref, ')')),
  CalcKeySpec(
    '%',
    ButtonType.action,
    () => _append(ref, '%'),
    tooltip: 'Percentage',
  ),
  CalcKeySpec(
    '/',
    ButtonType.action,
    () => _append(ref, '/'),
    tooltip: 'Fraction',
  ),
];

/// A row of three digits and a right-hand operator.
CalcKeyRow digitRow(
  WidgetRef ref,
  String left,
  String middle,
  String right,
  String operator,
) => [
  CalcKeySpec(left, ButtonType.number, () => _append(ref, left)),
  CalcKeySpec(middle, ButtonType.number, () => _append(ref, middle)),
  CalcKeySpec(right, ButtonType.number, () => _append(ref, right)),
  CalcKeySpec(operator, ButtonType.operator, () => _append(ref, operator)),
];

/// The bottom numeric row: `0 . MOD +`.
CalcKeyRow zeroRow(WidgetRef ref) => [
  CalcKeySpec('0', ButtonType.number, () => _append(ref, '0')),
  CalcKeySpec('.', ButtonType.number, () => _append(ref, '.')),
  // A plain `mod` insert, and nothing else. This key previously carried an
  // undocumented long-press that did not do what its label implied; see the
  // Keypad class doc.
  CalcKeySpec(
    'MOD',
    ButtonType.scientific,
    () => _append(ref, 'mod'),
    tooltip: 'Remainder after division — insert "mod" into the expression',
  ),
  CalcKeySpec('+', ButtonType.operator, () => _append(ref, '+')),
];

/// The bottom action row: `AC ANS ⌫ =`.
CalcKeyRow actionRow(WidgetRef ref) => [
  CalcKeySpec('AC', ButtonType.clear, () {
    ref.read(calculatorProvider.notifier).clear();
    return true;
  }),
  CalcKeySpec(
    'ANS',
    ButtonType.action,
    () => _append(ref, 'Ans'),
    tooltip: 'Last Answer',
  ),
  CalcKeySpec('⌫', ButtonType.backspace, () {
    ref.read(calculatorProvider.notifier).delete();
    return true;
  }, tooltip: 'Delete the last character'),
  CalcKeySpec(
    '=',
    ButtonType.equals,
    _alwaysSucceeds,
    isEquals: true,
    onEvaluate: () => ref.read(calculatorProvider.notifier).evaluate(),
  ),
];

/// Placeholder action for the equals key, which runs through [CalcKeySpec.onEvaluate].
bool _alwaysSucceeds() => true;

/// The keys shown by whichever scientific panel is open.
///
/// Returns an empty row when no panel is open, which is what lets the keypad
/// size the slot without inspecting the panel enum itself.
CalcKeyRow expandedPanelRow(
  WidgetRef ref,
  CalculatorState state,
  ExpandedPanel panel,
) {
  final notifier = ref.read(calculatorProvider.notifier);

  switch (panel) {
    case ExpandedPanel.trig:
      return [
        CalcKeySpec(
          state.isDegreeMode ? 'Deg' : 'Rad',
          ButtonType.scientific,
          () {
            notifier.toggleDegreeMode();
            return true;
          },
          isActive: state.isDegreeMode,
        ),
        for (final base in const ['sin', 'cos', 'tan'])
          CalcKeySpec(
            trigKeyName(base, inv: state.isInvMode, hyp: state.isHypMode),
            ButtonType.scientific,
            () {
              _appendFn(
                ref,
                trigKeyName(base, inv: state.isInvMode, hyp: state.isHypMode),
              );
              return true;
            },
          ),
        CalcKeySpec('Inv', ButtonType.scientific, () {
          notifier.toggleInvMode();
          return true;
        }, isActive: state.isInvMode),
      ];

    case ExpandedPanel.log:
      return [
        CalcKeySpec('log\u2081\u2080', ButtonType.scientific, () {
          _appendFn(ref, 'log');
          return true;
        }),
        CalcKeySpec('ln', ButtonType.scientific, () {
          _appendFn(ref, 'ln');
          return true;
        }),
        CalcKeySpec('log\u2099', ButtonType.scientific, () {
          notifier.appendLogTemplate();
          return true;
        }),
        CalcKeySpec('e', ButtonType.scientific, () => _append(ref, 'e')),
      ];

    case ExpandedPanel.memory:
      return [
        CalcKeySpec('MC', ButtonType.scientific, () {
          notifier.memoryClear();
          return true;
        }),
        CalcKeySpec('MR', ButtonType.scientific, () {
          notifier.memoryRecall();
          return true;
        }),
        CalcKeySpec('M+', ButtonType.scientific, () {
          notifier.memoryAdd();
          return true;
        }),
        CalcKeySpec('M\u2212', ButtonType.scientific, () {
          notifier.memorySubtract();
          return true;
        }),
        CalcKeySpec('MS', ButtonType.scientific, () {
          notifier.memoryStore();
          return true;
        }),
      ];

    case ExpandedPanel.none:
      return const [];
  }
}
