import 'package:calc_flut_rs/generated/rust/bridge/converter.dart';
import 'package:calc_flut_rs/generated/rust/bridge/currency.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ConverterResultData {
  final String title;
  final String primaryValue;
  final String secondaryText;

  const ConverterResultData({
    required this.title,
    required this.primaryValue,
    required this.secondaryText,
  });

  bool get isEmpty => primaryValue.isEmpty;
}

// --- Currency API Service ---

/// A service responsible for fetching and caching live currency exchange rates
/// from an external API (frankfurter.app).
class CurrencyService {
  static const String _baseUrl = 'https://api.frankfurter.app/latest';
  static const String _cacheKey = 'currency_rates_cache';

  static const Map<String, double> _fallbackRates = {
    'USD': 1.0,
    'EUR': 0.92,
    'GBP': 0.79,
    'JPY': 150.0,
    'AUD': 1.52,
    'CAD': 1.36,
    'CHF': 0.90,
    'CNY': 7.20,
    'INR': 83.0,
  };

  /// Fetches the latest currency exchange rates relative to USD.
  /// Uses a local cache if available and less than 12 hours old, unless `forceRefresh` is true.
  Future<Map<String, double>> fetchRates({bool forceRefresh = false}) async {
    final prefs = await SharedPreferences.getInstance();

    if (!forceRefresh) {
      final cachedStr = prefs.getString(_cacheKey);
      if (cachedStr != null) {
        try {
          final data = jsonDecode(cachedStr) as Map<String, dynamic>;
          final timestamp = data['timestamp'] as int;
          // Cache for 24 hours (1 day)
          if (DateTime.now().millisecondsSinceEpoch - timestamp <
              24 * 60 * 60 * 1000) {
            return Map<String, double>.from(data['rates']);
          }
        } catch (e) {
          // Fall through to fetch
        }
      }
    }

    try {
      final response = await http.get(Uri.parse('$_baseUrl?base=USD'));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final ratesRaw = json['rates'] as Map<String, dynamic>;
        final rates = ratesRaw.map(
          (key, value) => MapEntry(key, (value as num).toDouble()),
        );
        // Add USD since it's the base
        rates['USD'] = 1.0;

        // Cache it
        await prefs.setString(
          _cacheKey,
          jsonEncode({
            'timestamp': DateTime.now().millisecondsSinceEpoch,
            'rates': rates,
          }),
        );

        return rates;
      } else {
        throw Exception('Failed to load exchange rates');
      }
    } catch (e) {
      // Fallback to cache if offline
      final cachedStr = prefs.getString(_cacheKey);
      if (cachedStr != null) {
        final data = jsonDecode(cachedStr) as Map<String, dynamic>;
        return Map<String, double>.from(data['rates']);
      }
      return _fallbackRates;
    }
  }
}

final currencyServiceProvider = Provider((ref) => CurrencyService());

// --- Static BMI Units ---
final List<FfiUnit> bmiWeightUnits = [
  const FfiUnit(
    id: 'kg',
    name: 'Weight',
    symbol: 'Kilograms',
    multiplier: 1.0,
    offset: 0.0,
  ),
  const FfiUnit(
    id: 'lb',
    name: 'Weight',
    symbol: 'Pounds',
    multiplier: 0.453592,
    offset: 0.0,
  ),
];

final List<FfiUnit> bmiHeightUnits = [
  const FfiUnit(
    id: 'cm',
    name: 'Height',
    symbol: 'Centimeters',
    multiplier: 1.0,
    offset: 0.0,
  ),
  const FfiUnit(
    id: 'm',
    name: 'Height',
    symbol: 'Meters',
    multiplier: 100.0,
    offset: 0.0,
  ),
  const FfiUnit(
    id: 'ft',
    name: 'Height',
    symbol: 'Feet',
    multiplier: 30.48,
    offset: 0.0,
  ),
  const FfiUnit(
    id: 'in',
    name: 'Height',
    symbol: 'Inches',
    multiplier: 2.54,
    offset: 0.0,
  ),
];

// --- State Management ---

/// Holds the state for the Unit Converter feature.
class ConverterState {
  final FfiConverterCategory? category;
  final FfiUnit? fromUnit;
  final FfiUnit? toUnit;
  final String inputValue;
  final String resultValue;
  final ConverterResultData? resultData;
  final Map<String, double> currencyRates;
  final bool isLoadingRates;

  // Custom states for special calculators
  final String discountPercentage;
  final String gstPercentage;
  final bool addGst;
  final String bmiHeight;
  final String bmiWeight;
  final FfiUnit? bmiWeightUnit;
  final FfiUnit? bmiHeightUnit;
  final String
  activeInput; // 'from', 'to', 'bmiWeight', 'bmiHeight', 'discountAmount', 'discountPercentage', 'gstAmount', 'gstPercentage'

  ConverterState({
    this.category,
    this.fromUnit,
    this.toUnit,
    this.inputValue = '',
    this.resultValue = '',
    this.resultData,
    this.currencyRates = const {},
    this.isLoadingRates = false,
    this.discountPercentage = '',
    this.gstPercentage = '',
    this.addGst = true,
    this.bmiHeight = '',
    this.bmiWeight = '',
    this.bmiWeightUnit,
    this.bmiHeightUnit,
    this.activeInput = 'from',
  });

  ConverterState copyWith({
    FfiConverterCategory? category,
    FfiUnit? fromUnit,
    FfiUnit? toUnit,
    bool clearUnits = false,
    String? inputValue,
    String? resultValue,
    ConverterResultData? resultData,
    bool clearResultData = false,
    Map<String, double>? currencyRates,
    bool? isLoadingRates,
    String? discountPercentage,
    String? gstPercentage,
    bool? addGst,
    String? bmiHeight,
    String? bmiWeight,
    FfiUnit? bmiWeightUnit,
    FfiUnit? bmiHeightUnit,
    String? activeInput,
  }) {
    return ConverterState(
      category: category ?? this.category,
      fromUnit: clearUnits ? null : (fromUnit ?? this.fromUnit),
      toUnit: clearUnits ? null : (toUnit ?? this.toUnit),
      inputValue: inputValue ?? this.inputValue,
      resultValue: resultValue ?? this.resultValue,
      resultData: clearResultData ? null : (resultData ?? this.resultData),
      currencyRates: currencyRates ?? this.currencyRates,
      isLoadingRates: isLoadingRates ?? this.isLoadingRates,
      discountPercentage: discountPercentage ?? this.discountPercentage,
      gstPercentage: gstPercentage ?? this.gstPercentage,
      addGst: addGst ?? this.addGst,
      bmiHeight: bmiHeight ?? this.bmiHeight,
      bmiWeight: bmiWeight ?? this.bmiWeight,
      bmiWeightUnit: bmiWeightUnit ?? this.bmiWeightUnit,
      bmiHeightUnit: bmiHeightUnit ?? this.bmiHeightUnit,
      activeInput: activeInput ?? this.activeInput,
    );
  }
}

/// A Riverpod Notifier managing the logic and state for all unit and currency conversions.
class ConverterNotifier extends Notifier<ConverterState> {
  @override
  ConverterState build() {
    // Cannot run async init directly in build synchronously returning state,
    // but we can trigger it.
    Future.microtask(() => _initCurrencyRates());
    return ConverterState();
  }

  Future<void> _initCurrencyRates() async {
    state = state.copyWith(isLoadingRates: true);
    try {
      final rates = await ref.read(currencyServiceProvider).fetchRates();
      state = state.copyWith(currencyRates: rates, isLoadingRates: false);
      if (state.category?.id == 'currency') {
        setCategory(state.category!);
      } else {
        _calculateResult();
      }
    } catch (e) {
      state = state.copyWith(isLoadingRates: false);
    }
  }

  Future<bool> refreshCurrencyRates() async {
    state = state.copyWith(isLoadingRates: true);
    try {
      final rates = await ref
          .read(currencyServiceProvider)
          .fetchRates(forceRefresh: true);
      state = state.copyWith(currencyRates: rates, isLoadingRates: false);
      if (state.category?.id == 'currency') {
        setCategory(state.category!);
      } else {
        _calculateResult();
      }
      return true;
    } catch (e) {
      state = state.copyWith(isLoadingRates: false);
      return false;
    }
  }

  void setCategory(FfiConverterCategory category) {
    if (category.id == 'currency') {
      // Create virtual units for currency
      if (state.currencyRates.isNotEmpty) {
        final units = state.currencyRates.keys
            .map(
              (k) => FfiUnit(
                id: k,
                name: k,
                symbol: k,
                multiplier: 1.0,
                offset: 0.0,
              ),
            )
            .toList();
        final cat = FfiConverterCategory(
          id: 'currency',
          name: 'Currency',
          iconName: 'currency_exchange',
          units: units,
          showSwapUnitsToggler: true,
          showResultSection: true,
        );
        state = state.copyWith(
          category: cat,
          fromUnit: units.isNotEmpty ? units.first : null,
          toUnit: units.length > 1
              ? units[1]
              : (units.isNotEmpty ? units.first : null),
          inputValue: '',
          resultValue: '',
          clearUnits: units.isEmpty,
        );
      } else {
        state = state.copyWith(
          category: category,
          inputValue: '',
          resultValue: '',
          clearUnits: true,
          activeInput: 'from',
        );
      }
    } else if (category.id == 'bmi') {
      state = state.copyWith(
        category: category,
        clearUnits: true,
        bmiWeightUnit: bmiWeightUnits.first,
        bmiHeightUnit: bmiHeightUnits.first,
        activeInput: 'bmiWeight',
        inputValue: '',
        resultValue: '',
        bmiWeight: '',
        bmiHeight: '',
      );
    } else if (category.id == 'discount' || category.id == 'gst') {
      state = state.copyWith(
        category: category,
        clearUnits: true,
        activeInput: category.id == 'discount' ? 'discountAmount' : 'gstAmount',
        inputValue: '',
        resultValue: '',
        discountPercentage: '',
        gstPercentage: '',
      );
    } else {
      state = state.copyWith(
        category: category,
        fromUnit: category.units.isNotEmpty ? category.units.first : null,
        toUnit: category.units.length > 1
            ? category.units[1]
            : (category.units.isNotEmpty ? category.units.first : null),
        inputValue: '',
        resultValue: '',
        discountPercentage: '',
        gstPercentage: '',
        bmiHeight: '',
        bmiWeight: '',
        clearUnits: category.units.isEmpty,
        activeInput: 'from',
      );
    }
    _calculateResult();
  }

  /// Sets the unit to convert from.
  void setFromUnit(FfiUnit unit) {
    state = state.copyWith(fromUnit: unit);
    _calculateResult();
  }

  /// Sets the unit to convert to.
  void setToUnit(FfiUnit unit) {
    state = state.copyWith(toUnit: unit);
    _calculateResult();
  }

  /// Swaps the "from" and "to" units.
  void swapUnits() {
    final temp = state.fromUnit;
    state = state.copyWith(fromUnit: state.toUnit, toUnit: temp);
    _calculateResult();
  }

  /// Appends a digit to the active input field.
  void onDigit(String digit) {
    final val = _getActiveValue();
    _setActiveValue(val + digit);
  }

  /// Deletes the last character from the active input field.
  void onDelete() {
    final val = _getActiveValue();
    if (val.isNotEmpty) {
      _setActiveValue(val.substring(0, val.length - 1));
    }
  }

  /// Clears all input and result values for the current category.
  void onClear() {
    if (state.category?.id == 'bmi') {
      state = state.copyWith(bmiWeight: '', bmiHeight: '', resultValue: '');
    } else if (state.category?.id == 'discount') {
      state = state.copyWith(
        inputValue: '',
        discountPercentage: '',
        resultValue: '',
      );
    } else if (state.category?.id == 'gst') {
      state = state.copyWith(
        inputValue: '',
        gstPercentage: '',
        resultValue: '',
      );
    } else {
      state = state.copyWith(inputValue: '', resultValue: '');
    }
    _calculateResult();
  }

  /// Appends a decimal point to the active input field.
  void onDot() {
    final val = _getActiveValue();
    if (!val.contains('.')) {
      if (val.isEmpty) {
        _setActiveValue('0.');
      } else {
        _setActiveValue('$val.');
      }
    }
  }

  String _getActiveValue() {
    switch (state.activeInput) {
      case 'to':
        return state.resultValue;
      case 'bmiWeight':
        return state.bmiWeight;
      case 'bmiHeight':
        return state.bmiHeight;
      case 'discountAmount':
        return state.inputValue;
      case 'discountPercentage':
        return state.discountPercentage;
      case 'gstAmount':
        return state.inputValue;
      case 'gstPercentage':
        return state.gstPercentage;
      default:
        return state.inputValue;
    }
  }

  void _setActiveValue(String val) {
    switch (state.activeInput) {
      case 'to':
        state = state.copyWith(resultValue: val);
        break;
      case 'bmiWeight':
        state = state.copyWith(bmiWeight: val);
        break;
      case 'bmiHeight':
        state = state.copyWith(bmiHeight: val);
        break;
      case 'discountPercentage':
        state = state.copyWith(discountPercentage: val);
        break;
      case 'gstPercentage':
        state = state.copyWith(gstPercentage: val);
        break;
      case 'discountAmount':
      case 'gstAmount':
      case 'from':
      default:
        state = state.copyWith(inputValue: val);
        break;
    }
    _calculateResult();
  }

  void setActiveInput(String inputId) {
    state = state.copyWith(activeInput: inputId);
  }

  void setBmiWeightUnit(FfiUnit unit) {
    state = state.copyWith(bmiWeightUnit: unit);
    _calculateResult();
  }

  void setBmiHeightUnit(FfiUnit unit) {
    state = state.copyWith(bmiHeightUnit: unit);
    _calculateResult();
  }

  // Setters for special fields
  void setDiscountPercentage(String val) {
    state = state.copyWith(discountPercentage: val);
    _calculateResult();
  }

  void setGstPercentage(String val) {
    state = state.copyWith(gstPercentage: val);
    _calculateResult();
  }

  void toggleAddGst() {
    state = state.copyWith(addGst: !state.addGst);
    _calculateResult();
  }

  void setBmiHeight(String val) {
    state = state.copyWith(bmiHeight: val);
    _calculateResult();
  }

  void setBmiWeight(String val) {
    state = state.copyWith(bmiWeight: val);
    _calculateResult();
  }

  void _calculateResult() {
    final catId = state.category?.id;
    if (catId == null) return;

    final isEmptyInput = state.inputValue.isEmpty;

    if (catId == 'currency') {
      final from = state.fromUnit?.id;
      final to = state.toUnit?.id;
      if (from != null &&
          to != null &&
          state.currencyRates.containsKey(from) &&
          state.currencyRates.containsKey(to)) {
        final isReverse = state.activeInput == 'to';
        final sourceValue = isReverse ? state.resultValue : state.inputValue;
        final isEmpty = sourceValue.isEmpty;

        if (isEmpty) {
          state = state.copyWith(
            inputValue: isReverse ? '' : state.inputValue,
            resultValue: isReverse ? state.resultValue : '',
            resultData: ConverterResultData(
              title: isReverse ? 'Reverse Conversion Mode' : 'Result',
              primaryValue: '0 $to',
              secondaryText:
                  '1 $from = ${_formatResult(state.currencyRates[to]! / state.currencyRates[from]!)} $to',
            ),
          );
        } else {
          final val = double.tryParse(sourceValue) ?? 0.0;
          final fromRate = state.currencyRates[from]!;
          final toRate = state.currencyRates[to]!;

          final res = isReverse
              ? val * (fromRate / toRate)
              : val * (toRate / fromRate);
          final formattedRes = _formatResult(res);

          state = state.copyWith(
            inputValue: isReverse ? formattedRes : state.inputValue,
            resultValue: isReverse ? state.resultValue : formattedRes,
            resultData: ConverterResultData(
              title: isReverse ? 'Reverse Conversion Mode' : 'Result',
              primaryValue: isReverse
                  ? '${state.resultValue} $to'
                  : '$formattedRes $to',
              secondaryText:
                  '1 $from = ${_formatResult(toRate / fromRate)} $to',
            ),
          );
        }
      } else {
        state = state.copyWith(resultValue: '', clearResultData: true);
      }
      return;
    }

    if (catId == 'discount') {
      if (isEmptyInput) {
        state = state.copyWith(
          resultValue: '',
          resultData: const ConverterResultData(
            title: 'Final Price',
            primaryValue: '0',
            secondaryText: 'Amount Saved: 0',
          ),
        );
      } else {
        final price = double.tryParse(state.inputValue) ?? 0.0;
        final percent = double.tryParse(state.discountPercentage) ?? 0.0;
        final res = calculateDiscount(
          originalPrice: price,
          discountPercentage: percent,
        );
        state = state.copyWith(
          resultData: ConverterResultData(
            title: 'Final Price',
            primaryValue: _formatResult(res.finalPrice),
            secondaryText: 'Amount Saved: ${_formatResult(res.amountSaved)}',
          ),
        );
      }
      return;
    }

    if (catId == 'gst') {
      if (isEmptyInput) {
        state = state.copyWith(
          resultValue: '',
          resultData: const ConverterResultData(
            title: 'Total Amount',
            primaryValue: '0',
            secondaryText: 'GST: 0\nBase: 0',
          ),
        );
      } else {
        final amt = double.tryParse(state.inputValue) ?? 0.0;
        final percent = double.tryParse(state.gstPercentage) ?? 0.0;
        final res = calculateGst(
          amount: amt,
          gstPercentage: percent,
          addGst: state.addGst,
        );
        state = state.copyWith(
          resultData: ConverterResultData(
            title: 'Total Amount',
            primaryValue: _formatResult(res.totalAmount),
            secondaryText:
                'GST: ${_formatResult(res.gstAmount)}\nBase: ${_formatResult(res.originalAmount)}',
          ),
        );
      }
      return;
    }

    if (catId == 'bmi') {
      final h = double.tryParse(state.bmiHeight) ?? 0.0;
      final w = double.tryParse(state.bmiWeight) ?? 0.0;

      if (h == 0 || w == 0) {
        state = state.copyWith(
          resultValue: '',
          resultData: const ConverterResultData(
            title: 'BMI',
            primaryValue: '0',
            secondaryText: 'Enter weight and height',
          ),
        );
        return;
      }

      final hUnit = state.bmiHeightUnit;
      final wUnit = state.bmiWeightUnit;

      final weightKg = wUnit != null ? (w * wUnit.multiplier) : w;
      final heightM = hUnit != null
          ? (h * hUnit.multiplier) / 100.0
          : h / 100.0;

      final res = calculateBmi(weightKg: weightKg, heightM: heightM);
      if (res.bmi > 0) {
        state = state.copyWith(
          resultValue: _formatResult(res.bmi),
          resultData: ConverterResultData(
            title: 'BMI',
            primaryValue: _formatResult(res.bmi),
            secondaryText: res.category,
          ),
        );
      } else {
        state = state.copyWith(resultValue: '', clearResultData: true);
      }
      return;
    }

    if (catId == 'numeral') {
      // For numeral, we need fromBase and toBase based on units
      final fromBase = _getBaseFromUnit(state.fromUnit?.id);
      final toBase = _getBaseFromUnit(state.toUnit?.id);
      if (fromBase != null && toBase != null) {
        final isReverse = state.activeInput == 'to';
        final sourceValue = isReverse ? state.resultValue : state.inputValue;
        final isEmpty = sourceValue.isEmpty;

        if (isEmpty) {
          state = state.copyWith(
            inputValue: isReverse ? '' : state.inputValue,
            resultValue: isReverse ? state.resultValue : '',
            resultData: ConverterResultData(
              title: isReverse ? 'Reverse Conversion Mode' : 'Result',
              primaryValue: '0',
              secondaryText: '= 0 (Base $fromBase)',
            ),
          );
        } else {
          final res = convertNumeral(
            value: sourceValue,
            fromBase: isReverse ? toBase : fromBase,
            toBase: isReverse ? fromBase : toBase,
          );

          state = state.copyWith(
            inputValue: isReverse ? (res ?? 'Invalid input') : state.inputValue,
            resultValue: isReverse
                ? state.resultValue
                : (res ?? 'Invalid input'),
            resultData: ConverterResultData(
              title: isReverse ? 'Reverse Conversion Mode' : 'Result',
              primaryValue: isReverse
                  ? state.resultValue
                  : (res ?? 'Invalid input'),
              secondaryText: res != null
                  ? '= ${isReverse ? res : state.inputValue} (Base $fromBase)'
                  : '',
            ),
          );
        }
      }
      return;
    }

    // Standard conversion
    final fromUnit = state.fromUnit;
    final toUnit = state.toUnit;
    if (fromUnit != null && toUnit != null) {
      final isReverse = state.activeInput == 'to';
      final sourceValue = isReverse ? state.resultValue : state.inputValue;
      final isEmpty = sourceValue.isEmpty;

      if (isEmpty) {
        state = state.copyWith(
          inputValue: isReverse ? '' : state.inputValue,
          resultValue: isReverse ? state.resultValue : '',
          resultData: ConverterResultData(
            title: isReverse ? 'Reverse Conversion Mode' : 'Result',
            primaryValue: '0 ${toUnit.symbol}',
            secondaryText: '= 0 ${fromUnit.symbol}',
          ),
        );
      } else {
        final val = double.tryParse(sourceValue);
        if (val != null) {
          final res = convertStandard(
            value: val,
            fromUnit: isReverse ? toUnit : fromUnit,
            toUnit: isReverse ? fromUnit : toUnit,
          );
          final formattedRes = _formatResult(res);
          state = state.copyWith(
            inputValue: isReverse ? formattedRes : state.inputValue,
            resultValue: isReverse ? state.resultValue : formattedRes,
            resultData: ConverterResultData(
              title: isReverse ? 'Reverse Conversion Mode' : 'Result',
              primaryValue: isReverse
                  ? '${state.resultValue} ${toUnit.symbol}'
                  : '$formattedRes ${toUnit.symbol}',
              secondaryText:
                  '= ${_formatResult(isReverse ? res : val)} ${fromUnit.symbol}',
            ),
          );
        } else {
          state = state.copyWith(
            inputValue: isReverse ? '' : state.inputValue,
            resultValue: isReverse ? state.resultValue : '',
            resultData: ConverterResultData(
              title: isReverse ? 'Reverse Conversion Mode' : 'Result',
              primaryValue: 'Invalid input',
              secondaryText: '',
            ),
          );
        }
      }
    }
  }

  String _formatResult(double val) {
    String s = val.toStringAsFixed(6);
    if (s.contains('.')) {
      s = s.replaceAll(RegExp(r'0*$'), '');
      if (s.endsWith('.')) {
        s = s.substring(0, s.length - 1);
      }
    }
    return s;
  }

  int? _getBaseFromUnit(String? id) {
    switch (id) {
      case 'dec':
        return 10;
      case 'bin':
        return 2;
      case 'oct':
        return 8;
      case 'hex':
        return 16;
      default:
        return null;
    }
  }
}

/// The global provider for the `ConverterNotifier`.
final converterProvider = NotifierProvider<ConverterNotifier, ConverterState>(
  () {
    return ConverterNotifier();
  },
);
