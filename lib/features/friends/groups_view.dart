import 'package:material_ui/material_ui.dart';

import '../../app_model.dart';
import '../../core/money.dart';
import '../../core/tokens.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../../ui/kit/glass.dart';
import '../../ui/kit/kit.dart';
import '../../ui/kit/motion.dart';
import '../add/add_spend_sheet.dart';
import 'new_group_dialog.dart';

/// Where you stand, in words: "you are owed ₹300" and so on.
String standing(int balance) => balance > 0
    ? 'you are owed ${formatInr(balance)}'
    : balance < 0
        ? 'you owe ${formatInr(-balance)}'
        : 'settled up';

Color standingColour(int balance) =>
    balance > 0 ? StubColors.owed : balance < 0 ? StubColors.owe : StubColors.muted;

/// Every group with what it has spent and where you stand in it.
class GroupsView extends StatelessWidget {
  const GroupsView({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StubScope.of(context).store;
    final groups = store.groups();
    final names = {for (final f in store.friends()) f.id: f.name};

    void addSpend(Group group) {
      showGlassSheet<void>(context, (_) => AddSpendSheet(group: group));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (groups.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 20, horizontal: 12),
            child: Text(
              'Make a group for flatmates or a trip, then split a spend with everyone at once.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        for (final (i, group) in groups.indexed)
          Entrance(
            key: ValueKey(group.id),
            index: i,
            child: Padding(
              padding: EdgeInsets.only(bottom: StubSpace.gap),
              child: _GroupRow(
                group: group,
                summary: store.groupSummary(group.id),
                names: names,
                onTap: () => showGlassSheet<void>(
                  context,
                  (_) => _GroupSheet(groupId: group.id, onAddSpend: addSpend),
                ),
              ),
            ),
          ),
        AddButton(key: Key('new-group'), label: 'New group', onTap: () => showNewGroup(context)),
      ],
    );
  }
}

/// Up to three overlapping friend initials.
class _Faces extends StatelessWidget {
  const _Faces({required this.names});

  final List<String> names;

  @override
  Widget build(BuildContext context) {
    final shown = names.take(3).toList();
    return SizedBox(
      width: 40.0 + (shown.length - 1) * 14,
      height: 40,
      child: Stack(
        children: [
          for (final (i, name) in shown.indexed)
            Positioned(
              left: i * 14.0,
              child: Container(
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                child: Avatar(name: name, radius: 18),
              ),
            ),
        ],
      ),
    );
  }
}

class _GroupRow extends StatelessWidget {
  const _GroupRow({required this.group, required this.summary, required this.names, required this.onTap});

  final Group group;
  final GroupSummary summary;
  final Map<int, String> names;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final people = group.memberIds.length + 1;
    return Pressable(
      key: Key('group-row-${group.id}'),
      scale: 0.97,
      onTap: onTap,
      child: SoftCard(
        child: Row(
          children: [
            _Faces(names: [for (final id in group.memberIds) names[id] ?? '']),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: StubColors.ink),
                  ),
                  Text(
                    '$people people · ${formatInr(summary.spent)} spent',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: StubColors.muted),
                  ),
                ],
              ),
            ),
            Text(
              standing(summary.balance),
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: standingColour(summary.balance)),
            ),
          ],
        ),
      ),
    );
  }
}

/// One group: where you stand with each member, its recent spends, and a
/// button to add a spend split with everyone.
class _GroupSheet extends StatelessWidget {
  const _GroupSheet({required this.groupId, required this.onAddSpend});

  final int groupId;
  final void Function(Group group) onAddSpend;

  @override
  Widget build(BuildContext context) {
    final model = StubScope.of(context);
    final store = model.store;
    final group = store.groups().where((g) => g.id == groupId).firstOrNull;
    if (group == null) return SizedBox(height: 120);
    final summary = store.groupSummary(groupId);
    final names = {for (final f in store.friends()) f.id: f.name};
    final spends = store.groupEntries(groupId, limit: 5);
    const label = TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: StubColors.muted);

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.86),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: const SheetGrab()),
              Text(group.name, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: StubColors.ink)),
              Text(
                '${formatInr(summary.spent)} spent together · ${standing(summary.balance)}',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: StubColors.muted),
              ),
              SizedBox(height: 16),
              Text('Balances', style: label),
              SizedBox(height: 6),
              for (final id in group.memberIds)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      Avatar(name: names[id] ?? '', radius: 16),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          names[id] ?? '',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: StubColors.ink),
                        ),
                      ),
                      Text(
                        _memberLine(summary.balances[id] ?? 0),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: standingColour(summary.balances[id] ?? 0),
                        ),
                      ),
                    ],
                  ),
                ),
              SizedBox(height: 14),
              Text('Recent spends', style: label),
              SizedBox(height: 6),
              if (spends.isEmpty)
                Text('Nothing yet.', style: Theme.of(context).textTheme.bodyMedium),
              for (final e in spends)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${e.title} · ${int.parse(e.day.substring(8))}/${int.parse(e.day.substring(5, 7))}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: StubColors.ink),
                        ),
                      ),
                      Text(
                        formatInr(e.total),
                        style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: StubColors.ink),
                      ),
                    ],
                  ),
                ),
              SizedBox(height: 18),
              PillButton(
                key: Key('group-add-spend'),
                label: 'Add a spend',
                onPressed: () {
                  Navigator.of(context).pop();
                  onAddSpend(group);
                },
              ),
              Center(
                child: TextButton(
                  key: Key('group-remove'),
                  onPressed: () {
                    model.write((s) => s.removeGroup(groupId));
                    Navigator.of(context).pop();
                  },
                  child: Text('Remove group', style: TextStyle(color: StubColors.owe, fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _memberLine(int balance) => balance > 0
    ? 'owes you ${formatInr(balance, decimals: balance % 100 != 0)}'
    : balance < 0
        ? 'you owe ${formatInr(-balance, decimals: balance % 100 != 0)}'
        : 'settled up';
