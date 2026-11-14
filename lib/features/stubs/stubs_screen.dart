import 'package:material_ui/material_ui.dart';

import '../../app_model.dart';
import '../../core/dates.dart';
import '../../core/money.dart';
import '../../core/tokens.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../../ui/kit/paper.dart';

/// One receipt per week of the month. Tap a week to unfold it.
class StubsScreen extends StatefulWidget {
  const StubsScreen({super.key});

  @override
  State<StubsScreen> createState() => _StubsScreenState();
}

class _StubsScreenState extends State<StubsScreen> {
  int? _open;

  @override
  Widget build(BuildContext context) {
    final model = StubScope.of(context);
    final store = model.store;
    final today = model.today;
    final days = daysInMonth(today);
    final currentWeek = (today.day - 1) ~/ 7;
    final open = _open ?? currentWeek;
    final weeklyBudget = store.budget * 7 ~/ days;

    final byWeek = <int, List<Entry>>{};
    for (final entry in store.entriesForMonth(today)) {
      final week = (int.parse(entry.day.substring(8)) - 1) ~/ 7;
      byWeek.putIfAbsent(week, () => []).add(entry);
    }

    return SafeArea(
      child: ListView(
        padding: EdgeInsets.fromLTRB(28, 12, 28, 32),
        children: [
          Text('Stubs', style: Theme.of(context).textTheme.titleMedium),
          Text(
            '${monthName(today)} · one receipt for each week',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          SizedBox(height: 16),
          for (var week = currentWeek; week >= 0; week--)
            Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: _WeekStub(
                key: Key('week-${week + 1}'),
                week: week,
                month: today,
                entries: byWeek[week] ?? const [],
                weeklyBudget: weeklyBudget,
                open: week == open,
                onTap: () => setState(() => _open = week == open ? -1 : week),
              ),
            ),
        ],
      ),
    );
  }
}

class _WeekStub extends StatelessWidget {
  const _WeekStub({
    super.key,
    required this.week,
    required this.month,
    required this.entries,
    required this.weeklyBudget,
    required this.open,
    required this.onTap,
  });

  final int week;
  final DateTime month;
  final List<Entry> entries;
  final int weeklyBudget;
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final total = entries.fold<int>(0, (sum, e) => sum + e.amount);
    final first = week * 7 + 1;
    final last = (first + 6).clamp(1, daysInMonth(month));
    final gap = weeklyBudget - total;
    final shown = entries.take(6).toList();
    return GestureDetector(
      onTap: onTap,
      child: AnimatedScale(
        scale: open ? 1 : 0.96,
        duration: Duration(milliseconds: 200),
        child: Paper(
          elevation: open ? 10 : 4,
          padding: EdgeInsets.fromLTRB(16, 14, 16, 18),
          child: AnimatedSize(
            duration: Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Week ${week + 1}',
                      style: receiptMono.copyWith(fontWeight: FontWeight.w500, color: StubColors.ink),
                    ),
                  ),
                  Text(
                    formatInr(total, decimals: true),
                    style: receiptMono.copyWith(fontWeight: FontWeight.w500, color: StubColors.ink),
                  ),
                ],
              ),
              if (open) ...[
                Text(
                  '$first–$last ${monthShort(month)}'.toUpperCase(),
                  style: receiptMono.copyWith(fontSize: 10, letterSpacing: 0.8, color: Color(0xFF7B7A82)),
                ),
                const DashedRule(),
                if (entries.isEmpty) Text('Nothing spent this week', style: receiptMono),
                for (final entry in shown)
                  Row(
                    children: [
                      Expanded(
                        child: Text(entry.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: receiptMono),
                      ),
                      SizedBox(width: 10),
                      Text(formatInr(entry.amount, decimals: true), style: receiptMono),
                    ],
                  ),
                if (entries.length > shown.length)
                  Text('+ ${entries.length - shown.length} more', style: receiptMono),
                const DashedRule(),
                Text(
                  gap >= 0
                      ? '${formatInr(gap)} under the weekly ${formatInr(weeklyBudget)}'
                      : '${formatInr(-gap)} over the weekly ${formatInr(weeklyBudget)}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: gap >= 0 ? StubColors.owed : StubColors.owe,
                  ),
                ),
              ],
            ],
          ),
          ),
        ),
      ),
    );
  }
}
