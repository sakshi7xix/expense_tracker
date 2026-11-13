/// Date keys used in the database: days are 'YYYY-MM-DD', months 'YYYY-MM'.
library;

String _two(int n) => n.toString().padLeft(2, '0');

String dayKey(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';

String monthKey(DateTime d) => '${d.year}-${_two(d.month)}';

int daysInMonth(DateTime d) => DateTime(d.year, d.month + 1, 0).day;

/// Days left in the month including [today].
int daysLeftInMonth(DateTime today) => daysInMonth(today) - today.day + 1;
