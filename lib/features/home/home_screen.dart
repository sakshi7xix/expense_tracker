import 'package:material_ui/material_ui.dart';

import '../../app_model.dart';
import '../../core/dates.dart';
import '../../core/money.dart';
import '../../core/tokens.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../../ui/kit/kit.dart';
import '../../ui/kit/motion.dart';
import '../notifications/bell.dart';
import '../receipts/spend_receipt.dart';
import '../settings/settings_screen.dart';

String _greeting(int hour) => hour < 12
    ? 'Good morning'
    : hour < 17
        ? 'Good afternoon'
        : 'Good evening';

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
    final profileName = model.auth.account?.name;
    // Monday to today.
    final weekSpent = [
      for (var d = today.subtract(Duration(days: today.weekday - 1)); !d.isAfter(today); d = d.add(Duration(days: 1)))
        store.spentOnDay(d),
    ].fold<int>(0, (a, b) => a + b);

    return SafeArea(
      child: ListView(
        padding: EdgeInsets.fromLTRB(StubSpace.gutter, 12, StubSpace.gutter, 96),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_greeting(model.now.hour), style: Theme.of(context).textTheme.bodyMedium),
                    Text(monthName(today), style: Theme.of(context).textTheme.titleMedium),
                  ],
                ),
              ),
              BellButton(),
              SizedBox(width: 10),
              Pressable(
                key: Key('open-settings'),
                scale: 0.9,
                label: 'Settings',
                onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => SettingsScreen())),
                child: profileName != null
                    ? Avatar(name: profileName, radius: 19)
                    : CircleAvatar(
                        radius: 19,
                        backgroundColor: StubColors.surface,
                        child: Icon(Icons.person_rounded, size: 20, color: StubColors.muted),
                      ),
              ),
            ],
          ),
          SizedBox(height: 14),
          Entrance(
            child: Pressable(tilt: true, scale: 0.98, haptic: false, onTap: () {}, child: _BalanceCard(budget: budget, spent: spent)),
          ),
          SizedBox(height: 20),
          Entrance(index: 1, child: Text('Today', style: Theme.of(context).textTheme.titleMedium)),
          SizedBox(height: 10),
          Entrance(
            index: 2,
            child: Row(
              children: [
                Expanded(child: _Tile(value: formatInr(store.spentOnDay(today)), label: 'Spent today')),
                SizedBox(width: StubSpace.gap),
                Expanded(child: _Tile(value: formatInr(weekSpent), label: 'This week')),
              ],
            ),
          ),
          SizedBox(height: 20),
          Entrance(index: 3, child: Text('This month', style: Theme.of(context).textTheme.titleMedium)),
          SizedBox(height: 10),
          if (entries.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('No spends yet. Tap + to add one.', style: Theme.of(context).textTheme.bodyMedium),
              ),
            ),
          for (final (i, entry) in entries.indexed)
            Entrance(
              key: ValueKey(entry.id),
              index: 4 + i,
              child: Padding(
                padding: EdgeInsets.only(bottom: StubSpace.gap),
                child: _SpendRow(entry: entry, category: names[entry.categoryId] ?? ''),
              ),
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
    // With no budget (no income, or not set yet) the card simply shows what
    // went out this month.
    final hasBudget = budget > 0;
    final left = hasBudget ? budget - spent : spent;
    final used = hasBudget ? (spent / budget).clamp(0.0, 1.0) : 0.0;
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
          TweenAnimationBuilder<double>(
            tween: Tween(end: left.toDouble()),
            duration: Duration(milliseconds: 650),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => Text(
              formatInr(value.round()),
              key: Key('left-amount'),
              style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900),
            ),
          ),
          Text(!hasBudget ? 'Spent this month' : left < 0 ? 'Over this month' : 'Left this month', style: faint),
          if (hasBudget) ...[
          SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: used.toDouble()),
              duration: Duration(milliseconds: 650),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 5,
                backgroundColor: Colors.white24,
                color: Color(0xFFFF9A5C),
              ),
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
          ] else ...[
            SizedBox(height: 12),
            Text('No monthly budget. You can add one in Settings.', key: Key('no-budget'), style: faint),
          ],
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
    return Pressable(
      scale: 0.97,
      onTap: () => showSpendReceipt(context, entry, category),
      onLongPress: () => _delete(context),
      child: SoftCard(
        child: Row(
          children: [
            CategoryIcon(category: category),
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
