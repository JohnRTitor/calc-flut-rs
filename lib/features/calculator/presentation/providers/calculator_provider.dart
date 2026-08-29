import 'dart:convert';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:calc_flut_rs/features/calculator/presentation/providers/calculator_state.dart';
import 'package:calc_flut_rs/generated/rust/bridge/calculator.dart'
    as rust;
import 'package:calc_flut_rs/generated/rust/bridge/history.dart'
    as rust_history;
import 'package:calc_flut_rs/features/history/presentation/providers/history_provider.dart';

part 'calculator_provider.g.dart';

/// A Riverpod Notifier that manages the state of the calculator.
///
/// Handles expression editing, mode switching, interacting with the Rust backend
/// for evaluation, and memory operations.
@riverpod
class Calculator extends _$Calculator {
  @override
  CalculatorState build() {
    _initMemoryState();
    return const CalculatorState();
  }

  Future<void> _initMemoryState() async {
    final mem = rust.memoryRecall();
    if (mem != null) {
      state = state.copyWith(hasMemory: true);
    }
  }

  /// Appends a new token (number, operator, function) to the current expression.
  /// Returns true if the token was successfully added.
  bool append(String text) {
    if (!_isValidAppend(text)) return false;

    if (state.showResult) {
      state = state.copyWith(
        tokens: [text],
        cursorIndex: 1,
        showResult: false,
        clearError: true,
        preview: '',
        clearExactResult: true,
      );
    } else {
      final newTokens = List<String>.from(state.tokens);

      if (state.cursorIndex < newTokens.length &&
          newTokens[state.cursorIndex] == '□') {
        newTokens[state.cursorIndex] = text;
        state = state.copyWith(
          tokens: newTokens,
          cursorIndex: state.cursorIndex + 1,
          clearError: true,
          clearExactResult: true,
        );
      } else if (state.cursorIndex > 0 &&
          newTokens[state.cursorIndex - 1] == '□') {
        newTokens[state.cursorIndex - 1] = text;
        state = state.copyWith(
          tokens: newTokens,
          clearError: true,
          clearExactResult: true,
        );
      } else {
        newTokens.insert(state.cursorIndex, text);
        state = state.copyWith(
          tokens: newTokens,
          cursorIndex: state.cursorIndex + 1,
          clearError: true,
          clearExactResult: true,
        );
      }
    }
    _updatePreview();
    return true;
  }

  bool _isValidAppend(String text) {
    final tokens = state.showResult ? <String>[] : state.tokens;
    final cursorIndex = state.showResult ? 0 : state.cursorIndex;

    final isOperator = [
      '+',
      '−',
      '×',
      '÷',
      '%',
      'mod',
      '^',
      '/',
    ].contains(text);
    final isMinus = text == '−';

    if (isOperator || text == '!') {
      if (cursorIndex == 0) {
        if (!isMinus) return false;
      }
    }

    String? prevToken;
    if (cursorIndex > 0 && tokens.isNotEmpty) {
      prevToken = tokens[cursorIndex - 1];
    }

    String? nextToken;
    if (cursorIndex < tokens.length) {
      nextToken = tokens[cursorIndex];
    }

    if (isOperator) {
      if (prevToken != null) {
        final isPrevOperator = [
          '+',
          '−',
          '×',
          '÷',
          '%',
          'mod',
          '^',
          '/',
        ].contains(prevToken);
        final isPrevOpenParen = prevToken.endsWith('(');

        if (isPrevOpenParen) {
          if (!isMinus) return false;
        }

        if (isPrevOperator) {
          if (!isMinus) return false;
          // Prevent multiple minus like 8 --- 4
          if (isMinus && prevToken == '−') {
            if (cursorIndex > 1) {
              final prevPrevToken = tokens[cursorIndex - 2];
              if ([
                '+',
                '−',
                '×',
                '÷',
                '%',
                'mod',
                '^',
                '/',
              ].contains(prevPrevToken)) {
                return false;
              }
            }
          }
        }
      }

      if (nextToken != null && nextToken == ')') {
        return false;
      }
    }

    if (text == '.') {
      int dots = 0;
      for (int i = cursorIndex - 1; i >= 0; i--) {
        final t = tokens[i];
        if (t == '.') {
          dots++;
        } else if (RegExp(r'^[0-9]+$').hasMatch(t)) {
          continue;
        } else {
          break;
        }
      }

      for (int i = cursorIndex; i < tokens.length; i++) {
        final t = tokens[i];
        if (t == '.') {
          dots++;
        } else if (RegExp(r'^[0-9]+$').hasMatch(t)) {
          continue;
        } else {
          break;
        }
      }
      if (dots > 0) return false;
    }

    if (text == ')') {
      int open = 0;
      int close = 0;
      for (int i = 0; i < cursorIndex; i++) {
        if (tokens[i].endsWith('(')) open++;
        if (tokens[i] == ')') close++;
      }
      if (close >= open) return false;

      if (prevToken != null && prevToken.endsWith('(')) {
        return false;
      }

      if (prevToken != null &&
          ['+', '−', '×', '÷', '%', 'mod', '^', '/'].contains(prevToken)) {
        return false;
      }
    }

    return true;
  }

  /// Deletes the token immediately preceding the cursor.
  void delete() {
    if (state.showResult) {
      state = state.copyWith(
        showResult: false,
        clearError: true,
        preview: '',
        clearExactResult: true,
      );
      return;
    }
    if (state.tokens.isNotEmpty && state.cursorIndex > 0) {
      final newTokens = List<String>.from(state.tokens);
      newTokens.removeAt(state.cursorIndex - 1);

      state = state.copyWith(
        tokens: newTokens,
        cursorIndex: state.cursorIndex - 1,
        clearError: true,
      );
      _updatePreview();
    }
  }

  /// Moves the cursor to a specific index within the expression tokens.
  void setCursor(int index) {
    if (index >= 0 && index <= state.tokens.length) {
      state = state.copyWith(cursorIndex: index);
    }
  }

  /// Clears the current expression and result, resetting the calculator state
  /// while preserving modes and memory.
  void clear() {
    state = CalculatorState(
      isScientificMode: state.isScientificMode,
      expandedPanel: state.expandedPanel,
      hasMemory: state.hasMemory,
    );
  }

  /// Toggles Function mode.

  /// Toggles the scientific mode, expanding or collapsing the advanced keypad.
  void toggleScientificMode() {
    if (state.isScientificMode) {
      // Collapse any open panel when turning off scientific mode
      state = state.copyWith(
        isScientificMode: false,
        expandedPanel: ExpandedPanel.none,
      );
    } else {
      state = state.copyWith(isScientificMode: true);
    }
  }

  /// Toggles the specified secondary keypad panel (e.g., trig, log, memory).
  void togglePanel(ExpandedPanel panel) {
    if (state.expandedPanel == panel) {
      state = state.copyWith(expandedPanel: ExpandedPanel.none);
    } else {
      state = state.copyWith(expandedPanel: panel);
    }
  }

  /// Toggles between Degree and Radian modes for trigonometric functions.
  void toggleDegreeMode() {
    state = state.copyWith(isDegreeMode: !state.isDegreeMode);
  }

  /// Toggles the inverse mode for trigonometric functions (e.g., sin to asin).
  void toggleInvMode() {
    state = state.copyWith(isInvMode: !state.isInvMode);
  }

  /// Toggles the hyperbolic mode for trigonometric functions (e.g., sin to sinh).
  void toggleHypMode() {
    state = state.copyWith(isHypMode: !state.isHypMode);
  }

  void _updatePreview() {
    final currentExpression = state.expression;
    if (currentExpression.isEmpty) {
      state = state.copyWith(preview: '');
      return;
    }
    try {
      final res = rust.evaluate(
        expression: currentExpression,
        isDegree: state.isDegreeMode,
        ansValue: state.ansValue,
      );

      state = state.copyWith(preview: res.formatted, clearError: true);
    } catch (e) {
      state = state.copyWith(preview: '', clearError: true);
    }
  }

  /// Evaluates the current expression using the Rust backend and updates the state.
  /// Returns true if the evaluation was successful.
  Future<bool> evaluate() async {
    if (state.showResult) {
      if (state.exactResult != null) {
        toggleDisplayFormat();
        return true;
      }
      return false;
    }

    final currentExpression = state.expression;
    if (currentExpression.isEmpty) return false;

    if (state.tokens.isNotEmpty) {
      final lastToken = state.tokens.last;
      if (['+', '−', '×', '÷', '%', 'mod', '^', '/'].contains(lastToken)) {
        return false;
      }
    }

    try {
      final res = rust.evaluate(
        expression: currentExpression,
        isDegree: state.isDegreeMode,
        ansValue: state.ansValue,
      );

      state = state.copyWith(
        result: res.formatted,
        showResult: true,
        clearError: true,
        ansValue: res.value,
        exactResult: res.exactFraction,
        displayAsFraction: res.exactFraction != null,
      );

      // Save history
      final newResult = res.exactFraction ?? res.formatted;
      rust_history.appHistoryAdd(
        category: 'calculator',
        preview: jsonEncode({
          'expression': currentExpression,
          'result': newResult,
        }),
        snapshot: jsonEncode({
          'tokens': state.tokens,
          'cursorIndex': state.cursorIndex,
          'isDegreeMode': state.isDegreeMode,
          'isScientificMode': state.isScientificMode,
          'ansValue': state.ansValue,
          'result': res.formatted,
          'exactResult': res.exactFraction,
        }),
      );

      // Wait to get valid path and save
      final historyNotifier = ref.read(historyProvider.notifier);
      await historyNotifier.saveHistoryToFile();
      historyNotifier.refresh();

      return true;
    } catch (e) {
      final cleanError = e
          .toString()
          .replaceAll('AnyhowException(', '')
          .replaceAll(RegExp(r'\)$'), '');

      state = state.copyWith(error: cleanError);
      return false;
    }
  }

  /// Toggles the display format of the result between decimal and exact fraction.
  void toggleDisplayFormat() {
    if (state.exactResult != null) {
      state = state.copyWith(displayAsFraction: !state.displayAsFraction);
    }
  }

  double? _getCurrentValue() {
    final currentExpression = state.expression;
    if (currentExpression.isEmpty) return null;
    try {
      return rust
          .evaluate(
            expression: currentExpression,
            isDegree: state.isDegreeMode,
            ansValue: state.ansValue,
          )
          .value;
    } catch (_) {
      return null;
    }
  }

  // Memory Operations

  /// Stores the current evaluation result in memory.
  bool memoryStore() {
    final val = _getCurrentValue();
    if (val != null) {
      rust.memoryStore(value: val);
      state = state.copyWith(hasMemory: true);

      return true;
    }
    return false;
  }

  /// Recalls the stored memory value and appends it to the expression.
  bool memoryRecall() {
    final val = rust.memoryRecall();
    if (val != null) {
      append(rust.formatResult(value: val, maxPrecision: 10));

      return true;
    }
    return false;
  }

  /// Adds the current evaluation result to the stored memory value.
  bool memoryAdd() {
    final val = _getCurrentValue();
    if (val != null) {
      rust.memoryAdd(value: val);
      state = state.copyWith(hasMemory: true);

      return true;
    }
    return false;
  }

  /// Subtracts the current evaluation result from the stored memory value.
  bool memorySubtract() {
    final val = _getCurrentValue();
    if (val != null) {
      rust.memorySubtract(value: val);
      state = state.copyWith(hasMemory: true);

      return true;
    }
    return false;
  }

  /// Clears the stored memory value.
  void memoryClear() {
    rust.memoryClear();
    state = state.copyWith(hasMemory: false);
  }

  /// Appends a custom logarithm template with placeholders for base and value.
  void appendLogTemplate() {
    if (state.showResult) {
      state = state.copyWith(
        tokens: ["log_", "□", "(", "□", ")"],
        cursorIndex: 1,
        showResult: false,
        clearError: true,
        preview: '',
        clearExactResult: true,
      );
    } else {
      final newTokens = List<String>.from(state.tokens);
      newTokens.insertAll(state.cursorIndex, ["log_", "□", "(", "□", ")"]);
      state = state.copyWith(
        tokens: newTokens,
        cursorIndex: state.cursorIndex + 1,
        clearError: true,
        clearExactResult: true,
      );
    }
    _updatePreview();
  }

  /// Appends a standard function template with a placeholder for the value (e.g., sin(□)).
  void appendFunctionTemplate(String functionName) {
    final template = [functionName, "(", "□", ")"];
    if (state.showResult) {
      state = state.copyWith(
        tokens: template,
        cursorIndex: 2, // Right before the □
        showResult: false,
        clearError: true,
        preview: '',
        clearExactResult: true,
      );
    } else {
      final newTokens = List<String>.from(state.tokens);
      newTokens.insertAll(state.cursorIndex, template);
      state = state.copyWith(
        tokens: newTokens,
        cursorIndex: state.cursorIndex + 2, // Right before the □
        clearError: true,
        clearExactResult: true,
      );
    }
    _updatePreview();
  }

  /// Restores the calculator state from a history snapshot.
  void restoreSnapshot(String snapshotJson) {
    try {
      final Map<String, dynamic> data = jsonDecode(snapshotJson);
      state = state.copyWith(
        tokens: List<String>.from(data['tokens'] ?? []),
        cursorIndex: data['cursorIndex'] as int? ?? 0,
        isDegreeMode: data['isDegreeMode'] as bool? ?? false,
        isScientificMode: data['isScientificMode'] as bool? ?? false,
        ansValue: (data['ansValue'] as num?)?.toDouble() ?? 0.0,
        result: data['result'] as String? ?? '',
        exactResult: data['exactResult'] as String?,
        showResult: true,
        displayAsFraction: data['exactResult'] != null,
        preview: '',
        clearError: true,
      );
    } catch (_) {
      // Failed to restore snapshot, ignore
    }
  }
}
