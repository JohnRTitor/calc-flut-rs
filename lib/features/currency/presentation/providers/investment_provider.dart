import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:calc_flut_rs/generated/rust/bridge/currency.dart';

enum InvestmentMode { oneTime, sip }

class InvestmentState {
  final InvestmentMode mode;

  // Inputs as strings for keypad support
  final String principalStr; // for oneTime
  final String monthlyContributionStr; // for SIP
  final String interestRateStr;
  final String yearsStr;

  // Advanced options
  final double compoundsPerYear; // 1, 2, 4, 12, 365

  final String activeInput;

  const InvestmentState({
    required this.mode,
    required this.principalStr,
    required this.monthlyContributionStr,
    required this.interestRateStr,
    required this.yearsStr,
    required this.compoundsPerYear,
    required this.activeInput,
  });

  InvestmentState copyWith({
    InvestmentMode? mode,
    String? principalStr,
    String? monthlyContributionStr,
    String? interestRateStr,
    String? yearsStr,
    double? compoundsPerYear,
    String? activeInput,
  }) {
    return InvestmentState(
      mode: mode ?? this.mode,
      principalStr: principalStr ?? this.principalStr,
      monthlyContributionStr:
          monthlyContributionStr ?? this.monthlyContributionStr,
      interestRateStr: interestRateStr ?? this.interestRateStr,
      yearsStr: yearsStr ?? this.yearsStr,
      compoundsPerYear: compoundsPerYear ?? this.compoundsPerYear,
      activeInput: activeInput ?? this.activeInput,
    );
  }

  double get principal => double.tryParse(principalStr) ?? 0.0;
  double get monthlyContribution =>
      double.tryParse(monthlyContributionStr) ?? 0.0;
  double get interestRate => double.tryParse(interestRateStr) ?? 0.0;
  double get years => double.tryParse(yearsStr) ?? 0.0;

  InvestmentResult get result {
    if (mode == InvestmentMode.oneTime) {
      return calculateInvestmentOneTime(
        principal: principal,
        annualInterestRate: interestRate,
        years: years,
        compoundsPerYear: compoundsPerYear,
      );
    } else {
      return calculateInvestmentSip(
        monthlyContribution: monthlyContribution,
        annualInterestRate: interestRate,
        years: years,
      );
    }
  }
}

class InvestmentNotifier extends Notifier<InvestmentState> {
  @override
  InvestmentState build() {
    return const InvestmentState(
      mode: InvestmentMode.oneTime,
      principalStr: '',
      monthlyContributionStr: '',
      interestRateStr: '',
      yearsStr: '',
      compoundsPerYear: 1.0, // Yearly compounding default
      activeInput: 'principal',
    );
  }

  void setMode(InvestmentMode mode) {
    state = state.copyWith(
      mode: mode,
      activeInput: mode == InvestmentMode.oneTime
          ? 'principal'
          : 'monthlyContribution',
    );
  }

  void setActiveInput(String inputId) {
    state = state.copyWith(activeInput: inputId);
  }

  void setCompoundsPerYear(double compounds) {
    state = state.copyWith(compoundsPerYear: compounds);
  }

  void onKeyPressed(String key) {
    String currentValue = '';
    switch (state.activeInput) {
      case 'principal':
        currentValue = state.principalStr;
        break;
      case 'monthlyContribution':
        currentValue = state.monthlyContributionStr;
        break;
      case 'interestRate':
        currentValue = state.interestRateStr;
        break;
      case 'years':
        currentValue = state.yearsStr;
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
      case 'monthlyContribution':
        state = state.copyWith(monthlyContributionStr: newValue);
        break;
      case 'interestRate':
        state = state.copyWith(interestRateStr: newValue);
        break;
      case 'years':
        state = state.copyWith(yearsStr: newValue);
        break;
    }
  }

  void reset() {
    state = InvestmentState(
      mode: state.mode,
      principalStr: '',
      monthlyContributionStr: '',
      interestRateStr: '',
      yearsStr: '',
      compoundsPerYear: 1.0,
      activeInput: state.mode == InvestmentMode.oneTime
          ? 'principal'
          : 'monthlyContribution',
    );
  }
}

final investmentProvider =
    NotifierProvider<InvestmentNotifier, InvestmentState>(() {
      return InvestmentNotifier();
    });
