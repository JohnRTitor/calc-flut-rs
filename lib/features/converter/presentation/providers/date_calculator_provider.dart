import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:calc_flut_rs/generated/rust/bridge/converter.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';

class DateCalculatorState {
  final DateTime fromDate;
  final DateTime toDate;

  const DateCalculatorState({required this.fromDate, required this.toDate});

  DateCalculatorState copyWith({DateTime? fromDate, DateTime? toDate}) {
    return DateCalculatorState(
      fromDate: fromDate ?? this.fromDate,
      toDate: toDate ?? this.toDate,
    );
  }

  int get totalDays => toDate.difference(fromDate).inDays;
  int get totalWeeks => totalDays ~/ 7;
  int get remainingDaysInWeek => totalDays % 7;

  // Approximate for simple stats
  double get totalMonths => totalDays / 30.436875;
  double get totalYears => totalDays / 365.2425;

  /// Returns a record with precise Years, Months, and Days between the two dates
  /// calculated using the Rust backend.
  DateDiffResult get preciseDifference {
    return calculateDateDifference(
      startTimestampMs: PlatformInt64Util.from(fromDate.millisecondsSinceEpoch),
      endTimestampMs: PlatformInt64Util.from(toDate.millisecondsSinceEpoch),
    );
  }
}

class DateCalculatorNotifier extends Notifier<DateCalculatorState> {
  @override
  DateCalculatorState build() {
    return DateCalculatorState(
      fromDate: DateTime.now(),
      toDate: DateTime.now().add(const Duration(days: 1)),
    );
  }

  void setFromDate(DateTime date) {
    state = state.copyWith(fromDate: date);
  }

  void setToDate(DateTime date) {
    state = state.copyWith(toDate: date);
  }

  void setToday() {
    final now = DateTime.now();
    state = state.copyWith(fromDate: now, toDate: now);
  }

  void setTomorrow() {
    final now = DateTime.now();
    state = state.copyWith(
      fromDate: now,
      toDate: now.add(const Duration(days: 1)),
    );
  }

  void setYesterday() {
    final now = DateTime.now();
    state = state.copyWith(
      fromDate: now,
      toDate: now.subtract(const Duration(days: 1)),
    );
  }

  void swapDates() {
    state = state.copyWith(fromDate: state.toDate, toDate: state.fromDate);
  }
}

final dateCalculatorProvider =
    NotifierProvider<DateCalculatorNotifier, DateCalculatorState>(() {
      return DateCalculatorNotifier();
    });
