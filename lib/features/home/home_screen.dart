import 'package:material_ui/material_ui.dart';

import '../../app_model.dart';
import '../../core/budget.dart';
import '../../core/money.dart';
import '../../core/tokens.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../../ui/kit/kit.dart';

/// Balance card, today's two numbers, and this month's spends.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final model = StubScope.of(context);
    final store = model.store;
    final today = model.today;
    final spent = store.spentInMonth(today);
    final budget = store.budget;
    final entries = store.entriesForMonth(today);
    final names = {for (final c in store.categories()) c.id: c.name};
    final perDay = perDayPaise(
      budget: budget,
      spent: spent,
      committed: store.committedFor(today),
      today: today,
    );

    return SafeArea(
      child: ListView(
        padding: EdgeInsets.fromLTRB(StubSpace.gutter, 12, StubSpace.gutter, 24),
        children: [
          Text('stub', style: Theme.of(context).textTheme.titleMedium),
          SizedBox(height: 14),
          _BalanceCard(budget: budget, spent: spent),
          SizedBox(height: 20),
          Text('Today', style: Theme.of(context).textTheme.titleMedium),
          SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _Tile(value: formatInr(store.spentOnDay(today)), label: 'Spent')),
              SizedBox(width: StubSpace.gap),
              Expanded(child: _Tile(value: formatInr(perDay), label: 'Per day')),
            ],
          ),
          SizedBox(height: 20),
          Text('This month', style: Theme.of(context).textTheme.titleMedium),
          SizedBox(height: 10),
          if (entries.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('No spends yet. Tap + to add one.', style: Theme.of(context).textTheme.bodyMedium),
              ),
            ),
          for (final entry in entries)
            Padding(
              padding: EdgeInsets.only(bottom: StubSpace.gap),
              child: _SpendRow(entry: entry, category: names[entry.categoryId] ?? ''),
            ),
        ],
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.budget, required this.spent});

  final int budget;
  final int spent;

  @override
  Widget build(BuildContext context) {
    final left = budget - spent;
    final used = budget <= 0 ? 0.0 : (spent / budget).clamp(0.0, 1.0);
    final faint = TextStyle(color: Colors.white70, fontSize: 12.5, fontWeight: FontWeight.w700);
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(StubRadius.card),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [StubColors.cardTop, StubColors.cardBottom],
        ),
        boxShadow: [BoxShadow(color: Color(0x471E1E28), blurRadius: 26, offset: Offset(0, 18))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            formatInr(left),
            key: Key('left-amount'),
            style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900),
          ),
          Text(left < 0 ? 'Over this month' : 'Left this month', style: faint),
          SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: used.toDouble(),
              minHeight: 5,
              backgroundColor: Colors.white24,
              color: StubColors.pop,
            ),
          ),
          SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${formatInr(spent)} spent', style: faint),
              Text('of ${formatInr(budget)}', style: faint),
            ],
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: StubColors.ink)),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: StubColors.muted)),
        ],
      ),
    );
  }
}

class _SpendRow extends StatelessWidget {
  const _SpendRow({required this.entry, required this.category});

  final Entry entry;
  final String category;

  void _delete(BuildContext context) {
    final model = StubScope.of(context);
    model.write((store) => store.deleteSpend(entry.id));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Deleted ${entry.title}'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => model.write((store) => store.restoreSpend(entry.id)),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final tags = [
      entry.day.substring(8),
      category,
      if (entry.isAutopay) 'Autopay',
      if (entry.isSplit) 'Split',
    ].join(' · ');
    return GestureDetector(
      onLongPress: () => _delete(context),
      child: SoftCard(
        child: Row(
          children: [
            Avatar(name: category),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: StubColors.ink),
                  ),
                  Text(tags, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: StubColors.muted)),
                ],
              ),
            ),
            Text(
              '−${formatInr(entry.amount)}',
              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: StubColors.ink),
            ),
          ],
        ),
      ),
    );
  }
}
