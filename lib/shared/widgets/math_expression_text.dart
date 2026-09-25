import 'package:flutter/material.dart';

/// Digit superscripts. Every digit has one, so multi-digit exponents such as
/// `10` render as `¹⁰` rather than falling back to `^10`.
const Map<String, String> _superscriptDigits = {
  '0': '⁰',
  '1': '¹',
  '2': '²',
  '3': '³',
  '4': '⁴',
  '5': '⁵',
  '6': '⁶',
  '7': '⁷',
  '8': '⁸',
  '9': '⁹',
};

/// Superscripts for the few symbols that appear in exponents.
const Map<String, String> _superscriptSymbols = {'+': '⁺', '-': '⁻'};

/// Superscript letters, for exponents like `xⁿ`.
const Map<String, String> _superscriptLetters = {
  'a': 'ᵃ', 'b': 'ᵇ', 'c': 'ᶜ', 'd': 'ᵈ', 'e': 'ᵉ', 'f': 'ᶠ',
  'g': 'ᵍ', 'h': 'ʰ', 'i': 'ⁱ', 'j': 'ʲ', 'k': 'ᵏ', 'l': 'ˡ',
  'm': 'ᵐ', 'n': 'ⁿ', 'o': 'ᵒ', 'p': 'ᵖ', 'r': 'ʳ', 's': 'ˢ',
  't': 'ᵗ', 'u': 'ᵘ', 'v': 'ᵛ', 'w': 'ʷ', 'x': 'ˣ', 'y': 'ʸ',
  'z': 'ᶻ',
};

bool _isLetter(String c) =>
    (c.compareTo('a') >= 0 && c.compareTo('z') <= 0) ||
    (c.compareTo('A') >= 0 && c.compareTo('Z') <= 0);

/// Converts one exponent body to superscript, or returns `null` if any part of
/// it has no superscript form.
String? _toSuperscript(String body) {
  final buffer = StringBuffer();
  for (final char in body.split('')) {
    final mapped =
        _superscriptDigits[char] ??
        _superscriptSymbols[char] ??
        _superscriptLetters[char.toLowerCase()];
    if (mapped == null) return null;
    buffer.write(mapped);
  }
  return buffer.toString();
}

/// Replaces `^<body>` with Unicode superscripts where a full mapping exists.
///
/// The exponent body is either a parenthesised group or a run of
/// letters/digits/leading sign. Anything without a superscript for every
/// character (`2n`, `1/2`, a symbol) is left exactly as typed: a wrong
/// superscript is worse than an honest caret.
String _superscriptPowers(String input) {
  final buffer = StringBuffer();
  var index = 0;

  while (index < input.length) {
    if (input[index] != '^') {
      buffer.write(input[index]);
      index++;
      continue;
    }

    var end = index + 1;
    String? body;
    if (end < input.length && input[end] == '(') {
      final close = input.indexOf(')', end);
      if (close != -1) {
        body = input.substring(end + 1, close);
        end = close + 1;
      }
    } else {
      final start = end;
      while (end < input.length &&
          (_isLetter(input[end]) || _isDigit(input[end]) ||
              input[end] == '+' || input[end] == '-')) {
        end++;
      }
      if (end > start) body = input.substring(start, end);
    }

    final superscript = body == null ? null : _toSuperscript(body);
    if (superscript == null) {
      // Not superscriptable: keep the caret and the body verbatim.
      buffer.write(input.substring(index, end));
    } else {
      buffer.write(superscript);
    }
    index = end;
  }

  return buffer.toString();
}

bool _isDigit(String c) => c.compareTo('0') >= 0 && c.compareTo('9') <= 0;

/// Drops an explicit `*` where the product is already unambiguous.
///
/// Only removes the sign between a digit and a following letter or bracket, so
/// `2*x + 1` becomes `2x + 1` and `2*(x + 1)` becomes `2(x + 1)`. A `*` between
/// two symbols (`x*y`) is kept: rendering it as `xy` would read as a single
/// variable named `xy`, which is a different expression.
String _dropImplicitMultiplication(String input) {
  final buffer = StringBuffer();
  for (var i = 0; i < input.length; i++) {
    final char = input[i];
    if (char == '*' &&
        i > 0 &&
        i + 1 < input.length &&
        _isDigit(input[i - 1]) &&
        (_isLetter(input[i + 1]) || input[i + 1] == '(')) {
      continue;
    }
    buffer.write(char);
  }
  return buffer.toString();
}

/// Formats a plain-text mathematical expression for display.
///
/// This is a **display formatter, not a parser**: it performs a fixed set of
/// textual substitutions and never changes what the expression means. Anything
/// it does not understand is passed through untouched, so an unexpected input
/// degrades to the original text rather than to something wrong.
///
/// Applies, in order:
/// 1. whitespace runs collapsed to single spaces;
/// 2. `^n` exponents mapped to Unicode superscripts where a full mapping exists;
/// 3. `*` dropped where the product is already unambiguous (`3*x` becomes `3x`).
///
/// Deliberately does *not* build stacked fractions, radical vincula or nested
/// layout. Exact fractions keep the app's existing flat `a/b` convention.
String formatMathForDisplay(String expression) {
  final collapsed = expression.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (collapsed.isEmpty) return collapsed;
  return _dropImplicitMultiplication(_superscriptPowers(collapsed));
}

/// Renders a mathematical expression string using the app's flat, single-line
/// expression convention, with light typesetting applied.
///
/// Deliberately small: it substitutes Unicode superscripts and drops redundant
/// multiplication signs, and does nothing else. A long expression scrolls
/// horizontally exactly as the calculator's result does, rather than being
/// re-laid-out across lines — introducing a multi-line expression renderer
/// would be a new visual language, not an extension of this one.
class MathExpressionText extends StatelessWidget {
  /// The expression to render, as produced by the symbolic backend.
  final String expression;

  /// Base style. Supplied by the caller so the expression inherits the
  /// surrounding result surface's colour and weight.
  final TextStyle? style;

  /// Horizontal alignment within the available width.
  final TextAlign textAlign;

  const MathExpressionText({
    super.key,
    required this.expression,
    this.style,
    this.textAlign = TextAlign.left,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      formatMathForDisplay(expression),
      style: style,
      textAlign: textAlign,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
    );
  }
}
