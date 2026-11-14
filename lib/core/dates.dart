/// Date keys used in the database: days are 'YYYY-MM-DD', months 'YYYY-MM'.
library;

String _two(int n) => n.toString().padLeft(2, '0');

String dayKey(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';

String monthKey(DateTime d) => '${d.year}-${_two(d.month)}';

int daysInMonth(DateTime d) => DateTime(d.year, d.month + 1, 0).day;

/// Days left in the month including [today].
int daysLeftInMonth(DateTime today) => daysInMonth(today) - today.day + 1;

const monthNames = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

String monthName(DateTime d) => monthNames[d.month - 1];

String monthShort(DateTime d) => monthNames[d.month - 1].substring(0, 3);

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

String weekdayShort(DateTime d) => _weekdays[d.weekday - 1];
