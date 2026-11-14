import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../app_model.dart';
import '../../core/budget.dart';
import '../../core/dates.dart';
import '../../core/money.dart';
import '../../core/tokens.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../../ui/kit/kit.dart';
import '../../ui/kit/motion.dart';
import 'bill_sheet.dart';

/// One short line about where a bill stands this month.
String billNote(BillStatus bill, DateTime today) {
  final day = '${bill.dueDay.clamp(1, daysInMonth(today))} ${monthShort(today)}';
  final left = daysUntilDue(bill.dueDay, today);
  return switch (bill.state) {
    BillState.paid => bill.autopay ? 'Auto-logged · $day' : 'Paid',
    BillState.skipped => 'Skipped this month',
    BillState.due when bill.autopay => 'Autopay · $day',
    BillState.due when left < 0 => 'Overdue · $day',
    BillState.due when left == 0 => 'Due today',
    BillState.due => 'Due $day · in $left ${left == 1 ? 'day' : 'days'}',
  };
}

/// Every regular payment with its day of the month. Autopays log themselves;
/// manual bills are ticked when paid.
class BillsScreen extends StatelessWidget {
  const BillsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final model = StubScope.of(context);
    final store = model.store;
    final today = model.today;
    final bills = store.billsFor(today);
    final names = {for (final c in store.categories()) c.id: c.name};
    final due = store.committedFor(today);
    final all = bills.fold<int>(0, (sum, b) => sum + b.amount);
    final done = bills.where((b) => b.state != BillState.due).length;
    final auto = bills.where((b) => b.autopay).length;
    final text = Theme.of(context).textTheme;

    return SafeArea(
      child: ListView(
        padding: EdgeInsets.fromLTRB(StubSpace.gutter, 12, StubSpace.gutter, 24),
        children: [
          Center(child: Text('Bills', style: text.titleMedium)),
          SizedBox(height: 16),
          Entrance(
            child: SoftCard(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Still due this month', style: _muted),
                  TweenAnimationBuilder<double>(
                    tween: Tween(end: due.toDouble()),
                    duration: Duration(milliseconds: 500),
                    curve: Curves.easeOutCubic,
                    builder: (context, v, _) => Text(
                      formatInr(v.round()),
                      key: Key('bills-due'),
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: StubColors.ink),
                    ),
                  ),
                  Text(
                    bills.isEmpty ? 'Nothing set up yet' : '$done of ${bills.length} done · $auto on autopay',
                    style: _muted,
                  ),
                  SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(end: all == 0 ? 0 : (all - due) / all),
                      duration: Duration(milliseconds: 500),
                      curve: Curves.easeOutCubic,
                      builder: (context, v, _) => LinearProgressIndicator(
                        value: v,
                        minHeight: 6,
                        backgroundColor: StubColors.soft,
                        color: StubColors.ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(monthName(today), style: text.titleMedium),
              if (bills.any((b) => !b.autopay)) Text('Tick when paid', style: _muted),
            ],
          ),
          SizedBox(height: 10),
          if (bills.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Add rent, electricity, subscriptions or anything else that comes round every month.',
                textAlign: TextAlign.center,
                style: text.bodyMedium,
              ),
            ),
          for (final (i, bill) in bills.indexed)
            Entrance(
              key: ValueKey(bill.id),
              index: 1 + i,
              child: Padding(
                padding: EdgeInsets.only(bottom: StubSpace.gap),
                child: _BillRow(bill: bill, category: names[bill.categoryId] ?? '', note: billNote(bill, today)),
              ),
            ),
          SizedBox(height: 4),
          Pressable(
            key: Key('add-bill'),
            scale: 0.97,
            label: 'Add a bill or autopay',
            onTap: () => showBillSheet(context),
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(StubRadius.row),
                border: Border.all(color: Color(0xFFD5D4D9), width: 1.5),
              ),
              child: ExcludeSemantics(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_rounded, size: 20, color: StubColors.muted),
                    SizedBox(width: 6),
                    Text(
                      'Add a bill or autopay',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: StubColors.muted),
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

const _muted = TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: StubColors.muted);

class _BillRow extends StatelessWidget {
  const _BillRow({required this.bill, required this.category, required this.note});

  final BillStatus bill;
  final String category;
  final String note;

  void _toggle(BuildContext context) {
    final model = StubScope.of(context);
    if (bill.state == BillState.due) {
      HapticFeedback.mediumImpact();
      model.write((s) => s.payBill(bill.id, day: model.today));
    } else {
      HapticFeedback.selectionClick();
      model.write((s) => s.unpayBill(bill.id, month: model.today));
    }
  }

  @override
  Widget build(BuildContext context) {
    final done = bill.state != BillState.due;
    return Pressable(
      key: Key('bill-row-${bill.id}'),
      scale: 0.97,
      onTap: () => showBillSheet(context, bill: bill),
      child: AnimatedOpacity(
        opacity: done ? 0.6 : 1,
        duration: Duration(milliseconds: 250),
        child: SoftCard(
          child: Row(
            children: [
              CategoryIcon(category: category),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            bill.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: StubColors.ink),
                          ),
                        ),
                        if (bill.autopay) ...[SizedBox(width: 6), AutoTag()],
                      ],
                    ),
                    Text(note, maxLines: 1, overflow: TextOverflow.ellipsis, style: _muted),
                  ],
                ),
              ),
              SizedBox(width: 8),
              Text(
                formatInr(bill.amount),
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: StubColors.ink),
              ),
              if (!bill.autopay && bill.state != BillState.skipped) ...[
                SizedBox(width: 10),
                Pressable(
                  key: Key('tick-${bill.id}'),
                  scale: 0.85,
                  haptic: false,
                  label: done ? 'Mark ${bill.name} as not paid' : 'Mark ${bill.name} as paid',
                  onTap: () => _toggle(context),
                  child: AnimatedContainer(
                    duration: Duration(milliseconds: 250),
                    curve: Curves.easeOutBack,
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: done ? StubColors.owed : Colors.transparent,
                      border: Border.all(color: done ? StubColors.owed : Color(0xFFC9C8CD), width: 1.8),
                    ),
                    child: Icon(Icons.check_rounded, size: 18, color: done ? Colors.white : Colors.transparent),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The little orange "Auto" label on autopay bills and spends.
class AutoTag extends StatelessWidget {
  const AutoTag({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: Color(0xFFFFF1E8), borderRadius: BorderRadius.circular(6)),
      child: Text('Auto', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: StubColors.pop)),
    );
  }
}
