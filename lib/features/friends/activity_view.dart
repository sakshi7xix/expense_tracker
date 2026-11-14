import 'package:material_ui/material_ui.dart';

import '../../app_model.dart';
import '../../core/dates.dart';
import '../../core/money.dart';
import '../../core/tokens.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../../ui/kit/kit.dart';
import '../../ui/kit/motion.dart';

/// Every split and payment with friends, newest first, grouped by day.
class ActivityView extends StatelessWidget {
  const ActivityView({super.key});

  @override
  Widget build(BuildContext context) {
    final model = StubScope.of(context);
    final items = model.store.activity(limit: 60);
    if (items.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text('Splits and payments with friends show up here.', style: Theme.of(context).textTheme.bodyMedium),
        ),
      );
    }
    final today = dayKey(model.today);
    final yesterday = dayKey(model.today.subtract(Duration(days: 1)));
    String heading(String day) {
      if (day == today) return 'Today';
      if (day == yesterday) return 'Yesterday';
      final d = DateTime.parse(day);
      return '${weekdayShort(d)} ${d.day} ${monthShort(d)}';
    }

    final children = <Widget>[];
    String? lastDay;
    for (final (i, item) in items.indexed) {
      if (item.day != lastDay) {
        lastDay = item.day;
        children.add(
          Padding(
            padding: EdgeInsets.fromLTRB(4, children.isEmpty ? 0 : 10, 4, 6),
            child: Text(
              heading(item.day),
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: StubColors.muted),
            ),
          ),
        );
      }
      children.add(
        Entrance(
          key: ValueKey(item.id),
          index: i.clamp(0, 8),
          child: Padding(padding: EdgeInsets.only(bottom: 6), child: _ActivityRow(item: item)),
        ),
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.item});

  final LedgerItem item;

  @override
  Widget build(BuildContext context) {
    final amount = item.amount.abs();
    final money = formatInr(amount, decimals: amount % 100 != 0);
    // A payment makes the balance move the other way to who paid.
    final at = DateTime.fromMillisecondsSinceEpoch(item.createdAt);
    final h = at.hour % 12 == 0 ? 12 : at.hour % 12;
    final time = item.createdAt == 0 ? '' : ' · $h:${at.minute.toString().padLeft(2, '0')} ${at.hour < 12 ? 'am' : 'pm'}';
    final line = item.isPayment
        ? 'Settled $money'
        : item.amount > 0
            ? '${item.friendName} owes you $money'
            : 'You owe ${item.friendName} $money';
    final colour = item.isPayment ? StubColors.muted : item.amount > 0 ? StubColors.owed : StubColors.owe;
    return SoftCard(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        children: [
          Avatar(name: item.friendName, radius: 17),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: StubColors.ink),
                ),
                Text.rich(
                  TextSpan(children: [
                    TextSpan(text: line, style: TextStyle(color: colour)),
                    TextSpan(text: time, style: TextStyle(color: StubColors.muted)),
                  ]),
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          if (item.isPayment) Icon(Icons.check_circle_rounded, size: 18, color: StubColors.owed),
        ],
      ),
    );
  }
}
