import 'package:flutter_test/flutter_test.dart';
import 'package:stub/core/budget.dart';
import 'package:stub/core/dates.dart';

void main() {
  final nov25 = DateTime(2026, 11, 25);

  test('date keys', () {
    expect(dayKey(DateTime(2026, 3, 7)), '2026-03-07');
    expect(monthKey(nov25), '2026-11');
    expect(daysInMonth(DateTime(2028, 2, 10)), 29);
    expect(daysLeftInMonth(nov25), 6);
  });

  test('per day spreads what is free over the days left', () {
    expect(perDayPaise(budget: 1500000, spent: 1117050, today: nov25), 63825);
  });

  test('per day sets bills aside and never goes negative', () {
    expect(perDayPaise(budget: 1500000, spent: 1117050, committed: 82950, today: nov25), 50000);
    expect(perDayPaise(budget: 1500000, spent: 1600000, today: nov25), 0);
  });

  test('pace gap is positive when under an even pace', () {
    expect(paceGapPaise(budget: 1500000, spent: 1117050, today: nov25), 132950);
    expect(paceGapPaise(budget: 1500000, spent: 1400000, today: nov25), -150000);
  });

  test('week totals group the month into sevens', () {
    final daily = List<int>.filled(30, 100);
    expect(weekTotals(daily), [700, 700, 700, 700, 200]);
    expect(weekTotals([]), isEmpty);
    expect(weeklyBudget(1500000, nov25), 350000);
  });

  test('days until a bill is due', () {
    expect(daysUntilDue(27, nov25), 2);
    expect(daysUntilDue(25, nov25), 0);
    expect(daysUntilDue(1, nov25), -24);
    expect(daysUntilDue(31, nov25), 5, reason: 'November ends on the 30th');
  });
}
