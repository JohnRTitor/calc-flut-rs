import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:calc_flut_rs/generated/rust/bridge/currency.dart';

enum TenureType { years, months }

class LoanCalculatorState {
  final String principalStr;
  final String interestRateStr;
  final String tenureStr;
  final TenureType tenureType;
  final String activeInput; // 'principal', 'interestRate', 'tenure'

  const LoanCalculatorState({
    required this.principalStr,
    required this.interestRateStr,
    required this.tenureStr,
    required this.tenureType,
    required this.activeInput,
  });

  LoanCalculatorState copyWith({
    String? principalStr,
    String? interestRateStr,
    String? tenureStr,
    TenureType? tenureType,
    String? activeInput,
  }) {
    return LoanCalculatorState(
      principalStr: principalStr ?? this.principalStr,
      interestRateStr: interestRateStr ?? this.interestRateStr,
      tenureStr: tenureStr ?? this.tenureStr,
      tenureType: tenureType ?? this.tenureType,
      activeInput: activeInput ?? this.activeInput,
    );
  }

  double get principal => double.tryParse(principalStr) ?? 0.0;
  double get interestRate => double.tryParse(interestRateStr) ?? 0.0;
  double get tenure => double.tryParse(tenureStr) ?? 0.0;

  int get tenureInMonths {
    if (tenureType == TenureType.months) {
      return tenure.toInt();
    } else {
      return (tenure * 12).toInt();
    }
  }

  LoanResult get result {
    return calculateLoanEmi(
      principal: principal,
      annualInterestRate: interestRate,
      tenureMonths: tenureInMonths,
    );
  }
}

class LoanCalculatorNotifier extends Notifier<LoanCalculatorState> {
  @override
  LoanCalculatorState build() {
    return const LoanCalculatorState(
      principalStr: '',
      interestRateStr: '',
      tenureStr: '',
      tenureType: TenureType.years,
      activeInput: 'principal',
    );
  }

  void setActiveInput(String inputId) {
    state = state.copyWith(activeInput: inputId);
  }

  void setTenureType(TenureType type) {
    state = state.copyWith(tenureType: type);
  }

  void onKeyPressed(String key) {
    String currentValue = '';
    switch (state.activeInput) {
      case 'principal':
        currentValue = state.principalStr;
        break;
      case 'interestRate':
        currentValue = state.interestRateStr;
        break;
      case 'tenure':
        currentValue = state.tenureStr;
        break;
    }

    if (key == 'C') {
      _updateCurrentInput('');
      return;
    }

    if (key == '⌫') {
      if (currentValue.isNotEmpty) {
        _updateCurrentInput(currentValue.substring(0, currentValue.length - 1));
      }
      return;
    }

    // Handle decimal point
    if (key == '.') {
      if (currentValue.isEmpty) {
        _updateCurrentInput('0.');
      } else if (!currentValue.contains('.')) {
        _updateCurrentInput(currentValue + key);
      }
      return;
    }

    // Normal digit
    if (currentValue == '0') {
      _updateCurrentInput(key);
    } else {
      // Basic length limit to prevent overflow
      if (currentValue.length < 15) {
        _updateCurrentInput(currentValue + key);
      }
    }
  }

  void _updateCurrentInput(String newValue) {
    switch (state.activeInput) {
      case 'principal':
        state = state.copyWith(principalStr: newValue);
        break;
      case 'interestRate':
        state = state.copyWith(interestRateStr: newValue);
        break;
      case 'tenure':
        state = state.copyWith(tenureStr: newValue);
        break;
    }
  }

  void reset() {
    state = const LoanCalculatorState(
      principalStr: '',
      interestRateStr: '',
      tenureStr: '',
      tenureType: TenureType.years,
      activeInput: 'principal',
    );
  }
}

final loanCalculatorProvider =
    NotifierProvider<LoanCalculatorNotifier, LoanCalculatorState>(() {
      return LoanCalculatorNotifier();
    });
