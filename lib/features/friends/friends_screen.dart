import 'package:material_ui/material_ui.dart';

import '../../app_model.dart';
import '../../core/money.dart';
import '../../core/tokens.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../../ui/kit/glass.dart';
import '../../ui/kit/kit.dart';
import '../../ui/kit/motion.dart';
import '../account/sign_in_page.dart';
import '../notifications/bell.dart';
import 'activity_view.dart';
import 'add_friend_dialog.dart';
import 'friend_sheet.dart';
import 'groups_view.dart';

enum FriendsTab { friends, groups, activity }

/// What you are owed and what you owe, then friends, groups or activity.
class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  FriendsTab _tab = FriendsTab.friends;

  @override
  Widget build(BuildContext context) {
    final model = StubScope.of(context);
    final store = model.store;
    final text = Theme.of(context).textTheme;
    return SafeArea(
      child: ListView(
        padding: EdgeInsets.fromLTRB(StubSpace.gutter, 12, StubSpace.gutter, 24),
        children: [
          SizedBox(
            height: 40,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Text('Friends', style: text.titleMedium),
                Align(alignment: Alignment.centerRight, child: BellButton()),
              ],
            ),
          ),
          SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _Total(label: 'You are owed', paise: store.owedToYou, color: StubColors.owed)),
              SizedBox(width: StubSpace.gap),
              Expanded(child: _Total(label: 'You owe', paise: store.youOwe, color: StubColors.owe)),
            ],
          ),
          if (model.auth.available && model.auth.account == null) ...[
            SizedBox(height: 10),
            Pressable(
              key: Key('friends-sign-in'),
              scale: 0.97,
              label: 'Sign in to split on friends\' phones',
              onTap: () => showSignIn(context),
              child: Container(
                padding: EdgeInsets.all(14),
                decoration: BoxDecoration(color: Color(0xFFFFF1E8), borderRadius: BorderRadius.circular(StubRadius.row)),
                child: ExcludeSemantics(
                  child: Row(
                    children: [
                      Icon(Icons.cloud_sync_outlined, color: StubColors.pop),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Sign in so friends see your splits on their phones',
                          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: StubColors.ink),
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: StubColors.pop),
                    ],
                  ),
                ),
              ),
            ),
          ],
          SizedBox(height: 12),
          _Segments(value: _tab, onChanged: (t) => setState(() => _tab = t)),
          SizedBox(height: 12),
          AnimatedSwitcher(
            duration: Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutCubic,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween(begin: Offset(0, 0.03), end: Offset.zero).animate(animation),
                child: child,
              ),
            ),
            child: KeyedSubtree(
              key: ValueKey(_tab),
              child: switch (_tab) {
                FriendsTab.friends => _FriendsList(friends: store.friends()),
                FriendsTab.groups => GroupsView(),
                FriendsTab.activity => ActivityView(),
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Segments extends StatelessWidget {
  const _Segments({required this.value, required this.onChanged});

  final FriendsTab value;
  final ValueChanged<FriendsTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(4),
      decoration: BoxDecoration(color: StubColors.surface, borderRadius: BorderRadius.circular(22)),
      child: Row(
        children: [
          for (final tab in FriendsTab.values)
            Expanded(
              child: Semantics(
                selected: tab == value,
                button: true,
                child: GestureDetector(
                  key: Key('seg-${tab.name}'),
                  onTap: () => onChanged(tab),
                  child: AnimatedContainer(
                    duration: Duration(milliseconds: 180),
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: tab == value ? StubColors.ink : Colors.transparent,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(
                      '${tab.name[0].toUpperCase()}${tab.name.substring(1)}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: tab == value ? Colors.white : StubColors.muted,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FriendsList extends StatelessWidget {
  const _FriendsList({required this.friends});

  final List<FriendBalance> friends;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (friends.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(child: Text('Add a friend to start splitting.', style: Theme.of(context).textTheme.bodyMedium)),
          ),
        for (final (i, friend) in friends.indexed)
          Entrance(
            key: ValueKey(friend.id),
            index: i,
            child: Padding(
              padding: EdgeInsets.only(bottom: StubSpace.gap),
              child: _FriendRow(friend: friend),
            ),
          ),
        AddButton(key: Key('add-friend'), label: 'Add a friend', onTap: () => showAddFriend(context)),
      ],
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
      onTap: () => showGlassSheet<void>(context, (_) => FriendSheet(friendId: friend.id)),
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
