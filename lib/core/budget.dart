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
