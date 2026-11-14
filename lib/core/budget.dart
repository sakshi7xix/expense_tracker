import 'dart:math' as math;

import 'dates.dart';

/// What can be spent per day for the rest of the month, in paise, after
/// setting aside [committed] money for bills that are still due.
int perDayPaise({
  required int budget,
  required int spent,
  required DateTime today,
  int committed = 0,
}) {
  final free = budget - spent - committed;
  if (free <= 0) return 0;
  return free ~/ daysLeftInMonth(today);
}

/// Spending compared with an even pace through the month. Positive means
/// under pace (good), negative means over.
int paceGapPaise({
  required int budget,
  required int spent,
  required DateTime today,
}) {
  final evenPace = budget * today.day ~/ daysInMonth(today);
  return evenPace - spent;
}

/// Totals for each week of a month (days 1–7, 8–14, and so on) from the
/// month's [daily] totals. The last week may be short.
List<int> weekTotals(List<int> daily) {
  return [
    for (var start = 0; start < daily.length; start += 7)
      daily.skip(start).take(7).fold(0, (sum, day) => sum + day),
  ];
}

/// The monthly [budget] spread over a week of [month].
int weeklyBudget(int budget, DateTime month) => budget * 7 ~/ daysInMonth(month);

/// Days from [today] until a bill due on [dueDay] this month; negative when
/// the day has passed. A day past the month's end counts as its last day.
int daysUntilDue(int dueDay, DateTime today) => math.min(dueDay, daysInMonth(today)) - today.day;
