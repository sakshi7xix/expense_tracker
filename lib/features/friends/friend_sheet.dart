import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../app_model.dart';
import '../../core/money.dart';
import '../../core/tokens.dart';
import '../../data/store.dart';
import '../../ui/kit/kit.dart';

/// The message a reminder copies, e.g. "Hi Riya! Just a reminder that you owe me ₹60."
String reminderText(String name, int paise) {
  return 'Hi $name! Just a reminder that you owe me ${formatInr(paise, decimals: paise % 100 != 0)}. Thanks!';
}

/// One friend: balance, recent shared history, and settle up in full or part.
class FriendSheet extends StatefulWidget {
  const FriendSheet({super.key, required this.friendId});

  final int friendId;

  @override
  State<FriendSheet> createState() => _FriendSheetState();
}

class _FriendSheetState extends State<FriendSheet> {
  TextEditingController? _amount;

  @override
  void dispose() {
    _amount?.dispose();
    super.dispose();
  }

  /// Copies a friendly nudge to paste into any chat.
  void _remind(String name, int balance) {
    final messenger = ScaffoldMessenger.of(context);
    Clipboard.setData(ClipboardData(text: reminderText(name, balance)));
    Navigator.of(context).pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('Reminder copied. Paste it in a chat with $name.')));
  }

  @override
  Widget build(BuildContext context) {
    final model = StubScope.of(context);
    final store = model.store;
    final friend = store.friends().firstWhere((f) => f.id == widget.friendId);
    final balance = friend.balance;
    final history = store.activity(friendId: friend.id, limit: 4);
    _amount ??= TextEditingController(text: (balance.abs() / 100).toStringAsFixed(2));
    final headline = balance > 0
        ? '${friend.name} owes you ${formatInr(balance, decimals: true)}'
        : balance < 0
            ? 'You owe ${friend.name} ${formatInr(-balance, decimals: true)}'
            : 'All settled up';

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Avatar(name: friend.name, filled: true),
              SizedBox(width: 12),
              Text(friend.name, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          SizedBox(height: 14),
          Text(
            headline,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: balance > 0 ? StubColors.owed : balance < 0 ? StubColors.owe : StubColors.ink,
            ),
          ),
          SizedBox(height: 10),
          for (final item in history)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 5),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '${item.title} · ${item.day.substring(5)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: StubColors.ink),
                    ),
                  ),
                  Text(
                    '${item.amount > 0 ? '+' : '−'}${formatInr(item.amount.abs(), decimals: true)}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: item.amount > 0 ? StubColors.owed : StubColors.owe,
                    ),
                  ),
                ],
              ),
            ),
          if (balance != 0) ...[
            SizedBox(height: 10),
            TextField(
              key: Key('settle-field'),
              controller: _amount,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(prefixText: '₹ ', labelText: 'Amount paid'),
            ),
            SizedBox(height: 14),
            PillButton(
              key: Key('settle-button'),
              label: balance > 0 ? 'Record payment' : 'I paid this',
              onPressed: () {
                final paise = parseAmount(_amount!.text) ?? 0;
                if (paise <= 0) return;
                model.write((s) => s.settle(friend.id, paise, day: model.today));
                Navigator.of(context).pop();
              },
            ),
          ],
          if (balance > 0) ...[
            SizedBox(height: 10),
            FrostButton(
              key: Key('remind-button'),
              icon: Icons.notifications_active_outlined,
              label: 'Send a reminder',
              onPressed: () => _remind(friend.name, balance),
            ),
          ],
        ],
      ),
    );
  }
}
