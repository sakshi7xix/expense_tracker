import 'package:material_ui/material_ui.dart';

import '../../app_model.dart';
import '../../core/money.dart';
import '../../core/split.dart';
import '../../core/tokens.dart';
import '../../data/store.dart';
import '../../ui/kit/kit.dart';
import '../../ui/kit/motion.dart';
import '../friends/add_friend_dialog.dart';
import 'split_draft.dart';

const _methodLabels = {
  SplitMethod.equal: 'Equally',
  SplitMethod.exact: 'Amounts',
  SplitMethod.percent: 'Percent',
  SplitMethod.shares: 'Shares',
};

/// Everything about splitting one spend, kept out of the main form:
/// who is in, who paid, how to divide it, and who owes whom.
class SplitSheet extends StatefulWidget {
  const SplitSheet({super.key, required this.draft, required this.total});

  final SplitDraft draft;

  /// The spend's amount in paise, or null if none has been typed yet.
  final int? total;

  @override
  State<SplitSheet> createState() => _SplitSheetState();
}

class _SplitSheetState extends State<SplitSheet> {
  final _fields = <String, TextEditingController>{};

  SplitDraft get _draft => widget.draft;

  @override
  void dispose() {
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _field(String person) {
    return _fields.putIfAbsent(person, () => TextEditingController(text: _draft.values[person] ?? ''));
  }

  /// Runs a change that re-seeds the per-person numbers, then shows them.
  void _reseed(VoidCallback change) {
    setState(() {
      change();
      for (final person in _draft.people) {
        _field(person).text = _draft.values[person] ?? '';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = StubScope.of(context).store;
    final friends = store.friends();
    final names = {for (final f in friends) f.id: f.name};
    final total = widget.total;
    final result = total == null || !_draft.active ? null : _draft.result(total);
    final bad = result != null && !result.ok;
    final summary = !_draft.active
        ? const <String>[]
        : total == null
            ? ['Type an amount first']
            : result!.ok
                ? _draft.debtLines(result, names)
                : [_draft.problem(total, result)];
    String name(String person) => person == me ? 'You' : names[int.parse(person)] ?? '';

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + MediaQuery.of(context).viewInsets.bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.86),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: const SheetGrab()),
                Row(
                  children: [
                    Expanded(child: Text('Split', style: Theme.of(context).textTheme.titleMedium)),
                    if (total != null)
                      Text(formatInr(total, decimals: true), style: Theme.of(context).textTheme.titleMedium),
                  ],
                ),
                SizedBox(height: 14),
                SizedBox(
                  height: 74,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final f in friends)
                        _Person(
                          key: Key('friend-${f.id}'),
                          name: f.name,
                          selected: _draft.friends.contains(f.id),
                          onTap: () => _reseed(() => _draft.toggle(f.id, total ?? 0)),
                        ),
                      _Person(
                        key: Key('new-friend'),
                        name: 'Add',
                        add: true,
                        selected: false,
                        onTap: () async {
                          final id = await showAddFriend(context);
                          if (id != null && mounted) _reseed(() => _draft.toggle(id, total ?? 0));
                        },
                      ),
                    ],
                  ),
                ),
                AnimatedSize(
                  duration: Duration(milliseconds: 240),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: !_draft.active
                      ? Padding(
                          padding: EdgeInsets.symmetric(vertical: 10),
                          child: Text('Tap a friend to split with them.', style: Theme.of(context).textTheme.bodyMedium),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(height: 10),
                            SectionLabel('Paid by'),
                            SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                ChoicePill(
                                  key: Key('payer-me'),
                                  label: 'You',
                                  selected: _draft.payer == null,
                                  onTap: () => setState(() => _draft.payer = null),
                                ),
                                for (final id in _draft.friends)
                                  ChoicePill(
                                    key: Key('payer-$id'),
                                    label: names[id] ?? '',
                                    selected: _draft.payer == id,
                                    onTap: () => setState(() => _draft.payer = id),
                                  ),
                              ],
                            ),
                            SizedBox(height: 16),
                            SectionLabel('Divide it'),
                            SizedBox(height: 8),
                            Container(
                              padding: EdgeInsets.all(3),
                              decoration: BoxDecoration(color: StubColors.soft, borderRadius: BorderRadius.circular(14)),
                              child: Row(
                                children: [
                                  for (final method in SplitMethod.values)
                                    Expanded(
                                      child: Pressable(
                                        key: Key('method-${method.name}'),
                                        scale: 0.92,
                                        onTap: () => _reseed(() {
                                          _draft.method = method;
                                          _draft.prefill(total ?? 0);
                                        }),
                                        child: AnimatedContainer(
                                          duration: Duration(milliseconds: 150),
                                          height: 34,
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            color: _draft.method == method ? StubColors.ink : Colors.transparent,
                                            borderRadius: BorderRadius.circular(11),
                                          ),
                                          child: Text(
                                            _methodLabels[method]!,
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w800,
                                              color: _draft.method == method ? Colors.white : StubColors.muted,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            if (_draft.method != SplitMethod.equal)
                              for (final person in _draft.people)
                                Padding(
                                  padding: EdgeInsets.only(top: 8),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          name(person),
                                          style: TextStyle(fontWeight: FontWeight.w800, color: StubColors.ink),
                                        ),
                                      ),
                                      SizedBox(
                                        width: 110,
                                        child: TextField(
                                          key: Key('value-$person'),
                                          controller: _field(person),
                                          textAlign: TextAlign.right,
                                          keyboardType: TextInputType.numberWithOptions(decimal: true),
                                          decoration: InputDecoration(
                                            isDense: true,
                                            prefixText: _draft.method == SplitMethod.exact ? '₹ ' : null,
                                            suffixText: _draft.method == SplitMethod.percent ? '%' : null,
                                          ),
                                          onChanged: (text) => setState(() => _draft.values[person] = text),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            SizedBox(height: 14),
                            Container(
                              key: Key('split-summary'),
                              width: double.infinity,
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: bad ? Color(0xFFFBEDEA) : Color(0xFFFFF1E8),
                                borderRadius: BorderRadius.circular(StubRadius.control),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  for (final line in summary)
                                    Text(
                                      line,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: bad ? StubColors.owe : StubColors.ink,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                ),
                SizedBox(height: 16),
                Row(
                  children: [
                    if (_draft.active)
                      TextButton(
                        key: Key('split-clear'),
                        onPressed: () => setState(_draft.clear),
                        child: Text('Don\'t split'),
                      ),
                    if (_draft.active) SizedBox(width: 8),
                    Expanded(
                      child: PillButton(
                        key: Key('split-done'),
                        label: 'Done',
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Person extends StatelessWidget {
  const _Person({super.key, required this.name, required this.selected, required this.onTap, this.add = false});

  final String name;
  final bool selected;
  final bool add;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      child: Pressable(
        scale: 0.88,
        label: add ? 'Add a friend' : name,
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.only(right: 12),
          child: SizedBox(
            width: 54,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: Duration(milliseconds: 150),
                  padding: EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(width: 2, color: selected ? StubColors.ink : Colors.transparent),
                  ),
                  child: add
                      ? CircleAvatar(
                          radius: 21,
                          backgroundColor: StubColors.soft,
                          child: Icon(Icons.add_rounded, color: StubColors.muted),
                        )
                      : Avatar(name: name, filled: selected, radius: 21),
                ),
                SizedBox(height: 3),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                    color: selected ? StubColors.ink : StubColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
