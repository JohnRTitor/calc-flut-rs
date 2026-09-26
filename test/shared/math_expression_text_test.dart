import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:calc_flut_rs/shared/widgets/math_expression_text.dart';

void main() {
  group('formatMathForDisplay', () {
    test('maps single-digit exponents to superscripts', () {
      expect(formatMathForDisplay('x^2'), 'x²');
      expect(formatMathForDisplay('x^3 + 1'), 'x³ + 1');
    });

    test('maps multi-digit exponents, which Unicode supports', () {
      // Every digit has a superscript form, so x^10 reads better as x¹⁰ than
      // falling back to a caret.
      expect(formatMathForDisplay('x^10'), 'x¹⁰');
      expect(formatMathForDisplay('2x^100'), '2x¹⁰⁰');
    });

    test('maps negative exponents, including the sign', () {
      expect(formatMathForDisplay('x^-2'), 'x⁻²');
    });

    test('drops a * between a coefficient and a variable', () {
      expect(formatMathForDisplay('2*x'), '2x');
      expect(formatMathForDisplay('3*x^2'), '3x²');
      expect(formatMathForDisplay('2*x + 1'), '2x + 1');
    });

    test('drops a * between a coefficient and a bracket', () {
      expect(formatMathForDisplay('2*(x + 1)'), '2(x + 1)');
    });

    test('keeps a * between two variables, which would read as one name', () {
      // "xy" is a different expression from "x*y", so the sign must stay.
      expect(formatMathForDisplay('x*y'), 'x*y');
      expect(formatMathForDisplay('2*x*y'), '2x*y');
    });

    test('keeps a * between two brackets', () {
      expect(
        formatMathForDisplay('(x - 2)*(x + 2)'),
        '(x - 2)*(x + 2)',
      );
    });

    test('superscripts a parenthesised exponent when every part maps', () {
      expect(formatMathForDisplay('x^(2n)'), 'x²ⁿ');
      expect(formatMathForDisplay('x^(n+1)'), 'xⁿ⁺¹');
    });

    test('leaves an exponent as a caret when any part has no superscript', () {
      // A wrong superscript would be worse than an honest caret, so an
      // exponent containing a character without a mapping passes through whole.
      expect(formatMathForDisplay('x^(1/2)'), 'x^(1/2)');
      expect(formatMathForDisplay('x^(2/3)'), 'x^(2/3)');
    });

    test('keeps the * after a fraction, which is not a coefficient', () {
      // Antiderivatives are full of rational coefficients. Here the digit
      // closes a fraction, so collapsing would read as a mangled fraction.
      expect(formatMathForDisplay('1/3*x^3'), '1/3*x³');
      expect(formatMathForDisplay('1/2*x^2 + C'), '1/2*x² + C');
    });

    test('collapses whitespace runs', () {
      expect(formatMathForDisplay('  x^2   +   1  '), 'x² + 1');
    });

    test('returns an empty string unchanged', () {
      expect(formatMathForDisplay(''), '');
      expect(formatMathForDisplay('   '), '');
    });

    test('leaves an unrecognised expression alone', () {
      // Purely textual substitution: whatever it does not understand survives.
      expect(formatMathForDisplay('2*sqrt(2)'), '2sqrt(2)');
      expect(formatMathForDisplay('ln(x^2)'), 'ln(x²)');
    });

    test('handles a real backend result end to end', () {
      // Shapes the Rust side actually emits.
      expect(formatMathForDisplay('x^3 + x^2 + x + 1'), 'x³ + x² + x + 1');
      expect(formatMathForDisplay('(x - 2)*(x + 2)'), '(x - 2)*(x + 2)');
      expect(formatMathForDisplay('5*x'), '5x');
      expect(formatMathForDisplay('-x^(-2)'), '-x⁻²');
      // Indefinite integrals, constant included.
      expect(formatMathForDisplay('1/3*x^3 + C'), '1/3*x³ + C');
      expect(formatMathForDisplay('-cos(x) + C'), '-cos(x) + C');
    });

    test('lower-cases the imaginary unit', () {
      // The engine writes it as a capital I, which reads like a variable name.
      expect(formatMathForDisplay('I'), 'i');
      expect(formatMathForDisplay('-I'), '-i');
      expect(formatMathForDisplay('2*I'), '2i');
      expect(formatMathForDisplay('I, -I'), 'i, -i');
    });

    test('leaves an I that is part of a name alone', () {
      // That is a variable the user chose, not the imaginary unit.
      expect(formatMathForDisplay('Ix'), 'Ix');
      expect(formatMathForDisplay('Ix + 1'), 'Ix + 1');
      expect(formatMathForDisplay('xI'), 'xI');
      expect(formatMathForDisplay('I_1'), 'I_1');
    });
  });

  group('MathExpressionText', () {
    testWidgets('renders the formatted expression', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: MathExpressionText(expression: '2*x^2 + 1')),
        ),
      );

      expect(find.text('2x² + 1'), findsOneWidget);
    });

    testWidgets('stays on one line for a long expression', (tester) async {
      // The app's convention is a single horizontally-scrolling line, not a
      // multi-line layout, so the text must not wrap.
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 80,
              child: MathExpressionText(
                expression: 'x^10 + x^9 + x^8 + x^7 + x^6',
              ),
            ),
          ),
        ),
      );

      final text = tester.widget<Text>(find.byType(Text));
      expect(text.maxLines, 1);
      expect(text.softWrap, isFalse);
    });
  });
}
