import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../app_model.dart';
import '../../core/dates.dart';
import '../../core/money.dart';
import '../../core/tokens.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../../ui/kit/motion.dart';
import '../../ui/kit/paper.dart';

/// The month's weekly receipts on a turning 3D ring. Swipe sideways to spin
/// it, or tap a receipt at the side to bring it to the front.
class ReceiptsScreen extends StatefulWidget {
  const ReceiptsScreen({super.key});

  @override
  State<ReceiptsScreen> createState() => _ReceiptsScreenState();
}

class _ReceiptsScreenState extends State<ReceiptsScreen> with SingleTickerProviderStateMixin {
  static const _cardWidth = 236.0;
  static const _step = 0.62; // radians between neighbouring receipts
  static const _radius = 250.0;

  late final AnimationController _spin = AnimationController.unbounded(vsync: this);
  bool _started = false;
  int _snapped = -1;

  @override
  void initState() {
    super.initState();
    _spin.addListener(_tick);
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  /// A light click each time a new receipt reaches the front.
  void _tick() {
    final front = _spin.value.round();
    if (front != _snapped) {
      if (_snapped != -1) HapticFeedback.selectionClick();
      _snapped = front;
    }
  }

  void _settle(int target, int last) {
    final to = target.clamp(0, last).toDouble();
    if (StubMotion.reduced(context)) {
      _spin.value = to;
      return;
    }
    _spin.animateTo(to, duration: Duration(milliseconds: 520), curve: Curves.easeOutBack);
  }

  @override
  Widget build(BuildContext context) {
    final model = StubScope.of(context);
    final store = model.store;
    final today = model.today;
    final days = daysInMonth(today);
    final weeks = (days + 6) ~/ 7;
    final currentWeek = (today.day - 1) ~/ 7;
    final last = weeks - 1;
    final weeklyBudget = store.budget * 7 ~/ days;

    if (!_started) {
      _started = true;
      _spin.value = currentWeek.toDouble();
      _snapped = currentWeek;
    }

    final byWeek = <int, List<Entry>>{};
    for (final entry in store.entriesForMonth(today)) {
      final week = (int.parse(entry.day.substring(8)) - 1) ~/ 7;
      byWeek.putIfAbsent(week, () => []).add(entry);
    }
    int totalOf(int week) => (byWeek[week] ?? const []).fold<int>(0, (s, e) => s + e.amount);
    final text = Theme.of(context).textTheme;

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(StubSpace.gutter, 12, StubSpace.gutter, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Receipts', style: text.titleMedium),
                Text('${monthName(today)} · swipe to turn the weeks', style: text.bodyMedium),
              ],
            ),
          ),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragStart: (_) => _spin.stop(),
              onHorizontalDragUpdate: (d) {
                _spin.value = (_spin.value - d.delta.dx / 190).clamp(-0.4, last + 0.4);
              },
              onHorizontalDragEnd: (d) {
                final fling = -(d.primaryVelocity ?? 0) / 1400;
                _settle((_spin.value + fling.clamp(-1.0, 1.0)).round(), last);
              },
              child: AnimatedBuilder(
                animation: _spin,
                builder: (context, _) {
                  final pos = _spin.value;
                  // Draw far receipts first so nearer ones sit on top.
                  final order = [for (var w = 0; w <= last; w++) w]
                    ..sort((a, b) => (b - pos).abs().compareTo((a - pos).abs()));
                  return Stack(
                    alignment: Alignment.topCenter,
                    clipBehavior: Clip.none,
                    children: [
                      for (final w in order)
                        if ((w - pos).abs() < 2.6)
                          _placed(
                            context,
                            offset: w - pos,
                            onTap: () => _settle(w, last),
                            child: _WeekReceipt(
                              key: Key('week-${w + 1}'),
                              week: w,
                              month: today,
                              entries: byWeek[w] ?? const [],
                              upcoming: w > currentWeek,
                            ),
                          ),
                    ],
                  );
                },
              ),
            ),
          ),
          AnimatedBuilder(
            animation: _spin,
            builder: (context, _) {
              final front = _spin.value.round().clamp(0, last);
              final total = totalOf(front);
              final gap = weeklyBudget - total;
              return Padding(
                padding: EdgeInsets.fromLTRB(StubSpace.gutter, 0, StubSpace.gutter, 18),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var w = 0; w <= last; w++)
                          AnimatedContainer(
                            duration: StubMotion.base,
                            curve: Curves.easeOutCubic,
                            margin: EdgeInsets.symmetric(horizontal: 3),
                            width: w == front ? 20 : 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: w == front ? StubColors.ink : Color(0xFFD5D4D9),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Week ${front + 1} · ${formatInr(total)}',
                      key: Key('week-summary'),
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: StubColors.ink),
                    ),
                    SizedBox(height: 2),
                    Text(
                      front > currentWeek
                          ? 'Still to come'
                          : gap >= 0
                              ? '${formatInr(gap)} under the weekly ${formatInr(weeklyBudget)}'
                              : '${formatInr(-gap)} over the weekly ${formatInr(weeklyBudget)}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: front > currentWeek
                            ? StubColors.muted
                            : gap >= 0
                                ? StubColors.owed
                                : StubColors.owe,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  /// Puts one receipt on the ring: [offset] 0 is the front, ±1 the sides.
  Widget _placed(BuildContext context, {required double offset, required VoidCallback onTap, required Widget child}) {
    final angle = offset * _step;
    final x = _radius * math.sin(angle);
    final z = _radius * (1 - math.cos(angle));
    final near = 1 - math.min(1.0, offset.abs() / 2.6);
    return Positioned(
      top: 18,
      child: Transform(
        alignment: Alignment.topCenter,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.0011)
          ..translateByDouble(x, 0, z, 1)
          ..rotateY(-angle * 0.85),
        child: Opacity(
          opacity: (0.25 + 0.75 * near).clamp(0.0, 1.0),
          child: IgnorePointer(
            ignoring: offset.abs() < 0.5,
            child: GestureDetector(onTap: onTap, child: SizedBox(width: _cardWidth, child: child)),
          ),
        ),
      ),
    );
  }
}

class _WeekReceipt extends StatelessWidget {
  const _WeekReceipt({super.key, required this.week, required this.month, required this.entries, required this.upcoming});

  final int week;
  final DateTime month;
  final List<Entry> entries;
  final bool upcoming;

  @override
  Widget build(BuildContext context) {
    final total = entries.fold<int>(0, (sum, e) => sum + e.amount);
    final first = week * 7 + 1;
    final last = (first + 6).clamp(1, daysInMonth(month));
    final shown = entries.take(7).toList();
    final bold = receiptMono.copyWith(fontWeight: FontWeight.w500, color: StubColors.ink);
    return Paper(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Week ${week + 1}', textAlign: TextAlign.center, style: bold.copyWith(fontSize: 14, letterSpacing: 2)),
          Text(
            '$first–$last ${monthShort(month)}'.toUpperCase(),
            textAlign: TextAlign.center,
            style: receiptMono.copyWith(fontSize: 10, letterSpacing: 0.8, color: Color(0xFF7B7A82)),
          ),
          const DashedRule(),
          if (entries.isEmpty)
            Text(upcoming ? 'Not here yet' : 'Nothing spent', textAlign: TextAlign.center, style: receiptMono),
          for (final entry in shown)
            Row(
              children: [
                Expanded(child: Text(entry.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: receiptMono)),
                SizedBox(width: 10),
                Text(formatInr(entry.amount, decimals: true), style: receiptMono),
              ],
            ),
          if (entries.length > shown.length) Text('+ ${entries.length - shown.length} more', style: receiptMono),
          const DashedRule(),
          Row(
            children: [
              Expanded(child: Text('TOTAL', style: bold)),
              Text(formatInr(total, decimals: true), style: bold),
            ],
          ),
          SizedBox(height: 10),
          SizedBox(height: 26, child: CustomPaint(painter: BarcodePainter())),
        ],
      ),
    );
  }
}
