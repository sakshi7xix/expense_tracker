import 'package:material_ui/material_ui.dart';

import '../../app_model.dart';
import '../../core/money.dart';
import '../../core/tokens.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../../ui/kit/kit.dart';
import '../../ui/kit/motion.dart';
import 'add_friend_dialog.dart';

/// What you are owed and what you owe, friend by friend.
class FriendsScreen extends StatelessWidget {
  const FriendsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StubScope.of(context).store;
    final friends = store.friends();
    final text = Theme.of(context).textTheme;
    return SafeArea(
      child: ListView(
        padding: EdgeInsets.fromLTRB(StubSpace.gutter, 12, StubSpace.gutter, 24),
        children: [
          Text('Friends', style: text.titleMedium),
          SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _Total(label: 'You are owed', paise: store.owedToYou, color: StubColors.owed)),
              SizedBox(width: StubSpace.gap),
              Expanded(child: _Total(label: 'You owe', paise: store.youOwe, color: StubColors.owe)),
            ],
          ),
          SizedBox(height: 16),
          if (friends.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: Text('Add a friend to start splitting.', style: text.bodyMedium)),
            ),
          for (final (i, friend) in friends.indexed)
            Entrance(
              key: ValueKey(friend.id),
              index: 1 + i,
              child: Padding(
                padding: EdgeInsets.only(bottom: StubSpace.gap),
                child: _FriendRow(friend: friend),
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: Key('add-friend'),
              onPressed: () => showAddFriend(context),
              icon: Icon(Icons.add_rounded),
              label: Text('Add a friend'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Total extends StatelessWidget {
  const _Total({required this.label, required this.paise, required this.color});

  final String label;
  final int paise;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: StubColors.muted)),
          Text(formatInr(paise), style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: color)),
        ],
      ),
    );
  }
}

class _FriendRow extends StatelessWidget {
  const _FriendRow({required this.friend});

  final FriendBalance friend;

  @override
  Widget build(BuildContext context) {
    final balance = friend.balance;
    final status = balance > 0
        ? 'owes you'
        : balance < 0
            ? 'you owe'
            : 'settled up';
    return Pressable(
      key: Key('friend-row-${friend.id}'),
      scale: 0.97,
      onTap: () => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: StubColors.page,
        builder: (_) => _FriendSheet(friendId: friend.id),
      ),
      child: SoftCard(
        child: Row(
          children: [
            Avatar(name: friend.name, filled: balance > 0),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(friend.name, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: StubColors.ink)),
                  Text(status, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: StubColors.muted)),
                ],
              ),
            ),
            if (balance != 0)
              Text(
                formatInr(balance.abs(), decimals: balance.abs() % 100 != 0),
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: balance > 0 ? StubColors.owed : StubColors.owe,
                ),
              )
            else
              Icon(Icons.check_rounded, size: 18, color: StubColors.owed),
          ],
        ),
      ),
    );
  }
}

/// One friend: balance, recent shared history, and settle up in full or part.
class _FriendSheet extends StatefulWidget {
  const _FriendSheet({required this.friendId});

  final int friendId;

  @override
  State<_FriendSheet> createState() => _FriendSheetState();
}

class _FriendSheetState extends State<_FriendSheet> {
  TextEditingController? _amount;

  @override
  void dispose() {
    _amount?.dispose();
    super.dispose();
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
        ],
      ),
    );
  }
}
