import 'package:material_ui/material_ui.dart';

import '../../app_model.dart';
import '../../core/dates.dart';
import '../../core/money.dart';
import '../../core/tokens.dart';
import '../../data/store.dart';
import '../../ui/kit/kit.dart';
import '../../ui/kit/motion.dart';
import 'trend_chart.dart';

enum StatsRange { week, month, year }

/// Total for the chosen period, a trend line, and where the month went.
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  StatsRange _range = StatsRange.month;
  int? _selected;

  @override
  Widget build(BuildContext context) {
    final model = StubScope.of(context);
    final store = model.store;
    final today = model.today;

    late final List<int> values;
    late final List<String> labels;
    late final List<String> pointNames;
    late final String period;
    switch (_range) {
      case StatsRange.week:
        final days = [for (var i = 6; i >= 0; i--) today.subtract(Duration(days: i))];
        values = [for (final d in days) store.spentOnDay(d)];
        labels = [for (final d in days) weekdayShort(d)];
        pointNames = [for (final d in days) d == today ? 'Today' : '${weekdayShort(d)} ${d.day} ${monthShort(d)}'];
        period = 'Last 7 days';
      case StatsRange.month:
        values = store.dailyTotals(today).sublist(0, today.day);
        labels = [for (var d = 1; d <= today.day; d++) d == 1 || d % 5 == 0 ? '$d' : ''];
        pointNames = [for (var d = 1; d <= today.day; d++) '$d ${monthShort(today)}'];
        period = '${monthName(today)} ${today.year}';
      case StatsRange.year:
        final months = [for (var i = 5; i >= 0; i--) DateTime(today.year, today.month - i, 1)];
        values = [for (final m in months) store.spentInMonth(m)];
        labels = [for (final m in months) monthShort(m)];
        pointNames = [for (final m in months) '${monthShort(m)} ${m.year}'];
        period = 'Last 6 months';
    }
    final selected = (_selected ?? values.length - 1).clamp(0, values.length - 1).toInt();
    final total = values.fold<int>(0, (a, b) => a + b);

    final names = {for (final c in store.categories()) c.id: c.name};
    final byCategory = store.categoryTotals(today);
    final monthTotal = byCategory.values.fold<int>(0, (a, b) => a + b);
    final text = Theme.of(context).textTheme;

    return SafeArea(
      child: ListView(
        padding: EdgeInsets.fromLTRB(StubSpace.gutter, 12, StubSpace.gutter, 24),
        children: [
          Center(child: Text('Statistics', style: text.titleMedium)),
          SizedBox(height: 16),
          Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: total.toDouble()),
              duration: Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              builder: (context, v, _) => Text(
                formatInr(v.round()),
                key: Key('stats-total'),
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: StubColors.ink),
              ),
            ),
          ),
          Center(child: Text('$period · ${pointNames[selected]}', key: Key('stats-period'), style: text.bodyMedium)),
          SizedBox(height: 14),
          Container(
            padding: EdgeInsets.all(4),
            decoration: BoxDecoration(color: StubColors.surface, borderRadius: BorderRadius.circular(22)),
            child: Row(
              children: [
                for (final range in StatsRange.values)
                  Expanded(
                    child: GestureDetector(
                      key: Key('range-${range.name}'),
                      onTap: () => setState(() {
                        _range = range;
                        _selected = null;
                      }),
                      child: AnimatedContainer(
                        duration: Duration(milliseconds: 150),
                        height: 34,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: range == _range ? StubColors.ink : Colors.transparent,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Text(
                          '${range.name[0].toUpperCase()}${range.name.substring(1)}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: range == _range ? Colors.white : StubColors.muted,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(height: 8),
          TweenAnimationBuilder<double>(
            key: ValueKey(_range),
            tween: Tween(begin: StubMotion.reduced(context) ? 1 : 0, end: 1),
            duration: Duration(milliseconds: 900),
            curve: Curves.easeInOutCubic,
            builder: (context, drawn, _) => TrendChart(
              values: values,
              labels: labels,
              selected: selected,
              drawn: drawn,
              fromZero: _range != StatsRange.year,
              onSelect: (i) => setState(() => _selected = i),
            ),
          ),
          SizedBox(height: 12),
          Text('Top spending', style: text.titleMedium),
          SizedBox(height: 10),
          if (byCategory.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: Text('Nothing spent this month yet.', style: text.bodyMedium)),
            ),
          for (final (i, entry) in byCategory.entries.indexed)
            Entrance(
              key: ValueKey(entry.key),
              index: i,
              child: Padding(
              padding: EdgeInsets.only(bottom: StubSpace.gap),
              child: SoftCard(
                child: Row(
                  children: [
                    CategoryIcon(category: names[entry.key] ?? ''),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            names[entry.key] ?? '',
                            style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: StubColors.ink),
                          ),
                          Text(
                            '${(entry.value * 100 / monthTotal).round()}% of spending',
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: StubColors.muted),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '−${formatInr(entry.value)}',
                      style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: StubColors.ink),
                    ),
                  ],
                ),
              ),
            ),
            ),
        ],
      ),
    );
  }
}
