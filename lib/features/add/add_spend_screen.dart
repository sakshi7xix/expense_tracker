import 'package:material_ui/material_ui.dart';

import '../../app_model.dart';
import '../../core/money.dart';
import '../../core/split.dart';
import '../../core/tokens.dart';
import '../../data/store.dart';
import '../../ui/kit/kit.dart';
import '../friends/add_friend_dialog.dart';
import 'receipt_dialog.dart';

const _me = 'me';

const _methodLabels = {
  SplitMethod.equal: 'Equal',
  SplitMethod.exact: '₹',
  SplitMethod.percent: '%',
  SplitMethod.shares: 'Shares',
};

/// Amount, note, category and an optional split with friends.
class AddSpendScreen extends StatefulWidget {
  const AddSpendScreen({super.key});

  @override
  State<AddSpendScreen> createState() => _AddSpendScreenState();
}

class _AddSpendScreenState extends State<AddSpendScreen> {
  final _amount = TextEditingController();
  final _title = TextEditingController();
  final _values = <String, TextEditingController>{};
  final _friends = <int>{};
  int? _categoryId;
  int? _payer; // null means you paid
  SplitMethod _method = SplitMethod.equal;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _title.dispose();
    for (final c in _values.values) {
      c.dispose();
    }
    super.dispose();
  }

  List<String> get _people => [_me, for (final id in _friends) '$id'];

  TextEditingController _valueOf(String person) =>
      _values.putIfAbsent(person, TextEditingController.new);

  /// Starting numbers for the unequal methods: an even split.
  void _prefill() {
    final total = parseAmount(_amount.text) ?? 0;
    final people = _people;
    final even = computeShares(total: total, people: people, method: SplitMethod.equal);
    final basePercent = 100 ~/ people.length;
    for (final person in people) {
      _valueOf(person).text = switch (_method) {
        SplitMethod.equal => '',
        SplitMethod.exact => even.ok ? (even.shares[person]! / 100).toStringAsFixed(2) : '',
        SplitMethod.percent =>
          person == _me ? '${100 - basePercent * (people.length - 1)}' : '$basePercent',
        SplitMethod.shares => '1',
      };
    }
  }

  SplitResult? _split(int total) {
    if (_friends.isEmpty) return null;
    num read(String person) {
      final text = _valueOf(person).text;
      return _method == SplitMethod.exact ? (parseAmount(text) ?? 0) : (double.tryParse(text) ?? 0);
    }

    return computeShares(
      total: total,
      people: _people,
      method: _method,
      values: {for (final p in _people) p: read(p)},
    );
  }

  String _problem(int total, SplitResult result) {
    if (_method != SplitMethod.exact) return result.problem ?? '';
    final assigned = _people.fold<int>(0, (a, p) => a + (parseAmount(_valueOf(p).text) ?? 0));
    final gap = total - assigned;
    return gap > 0
        ? '${formatInr(gap, decimals: true)} left to assign'
        : '${formatInr(-gap, decimals: true)} too much';
  }

  List<String> _debtLines(SplitResult result, Map<int, String> names) {
    String name(String person) => person == _me ? 'You' : names[int.parse(person)] ?? '';
    final payer = _payer == null ? _me : '$_payer';
    return [
      for (final debt in debtsFor(payer: payer, shares: result.shares))
        debt.from == _me
            ? 'You owe ${name(debt.to)} ${formatInr(debt.paise, decimals: true)}'
            : debt.to == _me
                ? '${name(debt.from)} owes you ${formatInr(debt.paise, decimals: true)}'
                : '${name(debt.from)} owes ${name(debt.to)} ${formatInr(debt.paise, decimals: true)}',
    ];
  }

  Future<void> _save() async {
    final model = StubScope.of(context);
    final store = model.store;
    final total = parseAmount(_amount.text);
    if (total == null) {
      setState(() => _error = 'Type an amount, like 120');
      return;
    }
    final split = _split(total);
    if (split != null && !split.ok) {
      setState(() => _error = _problem(total, split));
      return;
    }
    final categories = store.categories();
    final categoryId = _categoryId ?? categories.first.id;
    final category = categories.firstWhere((c) => c.id == categoryId).name;
    final title = _title.text.trim().isEmpty ? category : _title.text.trim();
    final names = {for (final f in store.friends()) f.id: f.name};
    final mine = split == null ? total : split.shares[_me]!;

    model.write(
      (s) => s.addSpend(
        title: title,
        total: total,
        categoryId: categoryId,
        day: model.today,
        friendShares: split == null ? const {} : {for (final id in _friends) id: split.shares['$id']!},
        payerFriendId: _payer,
      ),
    );

    await showDialog<void>(
      context: context,
      builder: (_) => ReceiptDialog(
        lines: [
          (title, formatInr(total, decimals: true)),
          (category, ''),
          if (split != null) ...[
            ('', null),
            for (final line in _debtLines(split, names)) (line, ''),
            ('Your share', formatInr(mine, decimals: true)),
          ],
          ('', null),
          ('Left this month', formatInr(store.budget - store.spentInMonth(model.today), decimals: true)),
        ],
      ),
    );
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final store = StubScope.of(context).store;
    final categories = store.categories();
    final friends = store.friends();
    final names = {for (final f in friends) f.id: f.name};
    _friends.removeWhere((id) => !names.containsKey(id));
    final categoryId = _categoryId ?? categories.first.id;
    final total = parseAmount(_amount.text);
    final split = total == null ? null : _split(total);

    return Scaffold(
      appBar: AppBar(title: Text('New spend'), backgroundColor: StubColors.page, centerTitle: true),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: PillButton(key: Key('save-button'), label: 'Print stub', onPressed: _save),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(StubSpace.gutter, 8, StubSpace.gutter, 24),
        child: Column(
          children: [
            TextField(
              key: Key('amount-field'),
              controller: _amount,
              autofocus: true,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: StubColors.ink),
              decoration: InputDecoration(prefixText: '₹', hintText: '0', border: InputBorder.none, errorText: _error),
              onChanged: (_) => setState(() {
                _error = null;
                if (_method == SplitMethod.exact) _prefill();
              }),
            ),
            SizedBox(height: 8),
            SoftCard(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionLabel('What for'),
                  TextField(
                    key: Key('title-field'),
                    controller: _title,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(hintText: 'Chai, groceries, auto…', border: InputBorder.none),
                  ),
                  Divider(height: 20),
                  SectionLabel('Category'),
                  SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final c in categories)
                        ChoicePill(
                          label: c.name,
                          selected: c.id == categoryId,
                          onTap: () => setState(() => _categoryId = c.id),
                        ),
                    ],
                  ),
                  Divider(height: 28),
                  SectionLabel('Split with friends', trailing: _friends.isEmpty ? 'Tap to pick' : null),
                  SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final f in friends)
                        ChoicePill(
                          key: Key('friend-${f.id}'),
                          label: f.name,
                          selected: _friends.contains(f.id),
                          onTap: () => setState(() {
                            _friends.contains(f.id) ? _friends.remove(f.id) : _friends.add(f.id);
                            if (_payer != null && !_friends.contains(_payer)) _payer = null;
                            _error = null;
                            _prefill();
                          }),
                        ),
                      ChoicePill(
                        key: Key('new-friend'),
                        label: '+ Friend',
                        selected: false,
                        onTap: () async {
                          final id = await showAddFriend(context);
                          if (id != null && mounted) {
                            setState(() {
                              _friends.add(id);
                              _prefill();
                            });
                          }
                        },
                      ),
                    ],
                  ),
                  if (_friends.isNotEmpty) ..._splitControls(names, total, split),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _splitControls(Map<int, String> names, int? total, SplitResult? split) {
    String name(String person) => person == _me ? 'You' : names[int.parse(person)] ?? '';
    final summary = total == null || split == null
        ? ['Type an amount to split']
        : split.ok
            ? _debtLines(split, names)
            : [_problem(total, split)];
    final bad = split != null && !split.ok;
    return [
      SizedBox(height: 16),
      SectionLabel('Who paid'),
      SizedBox(height: 8),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          ChoicePill(
            key: Key('payer-me'),
            label: 'You',
            selected: _payer == null,
            onTap: () => setState(() => _payer = null),
          ),
          for (final id in _friends)
            ChoicePill(
              key: Key('payer-$id'),
              label: names[id] ?? '',
              selected: _payer == id,
              onTap: () => setState(() => _payer = id),
            ),
        ],
      ),
      SizedBox(height: 16),
      SectionLabel('How to split'),
      SizedBox(height: 8),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final method in SplitMethod.values)
            ChoicePill(
              key: Key('method-${method.name}'),
              label: _methodLabels[method]!,
              selected: _method == method,
              onTap: () => setState(() {
                _method = method;
                _error = null;
                _prefill();
              }),
            ),
        ],
      ),
      if (_method != SplitMethod.equal)
        for (final person in _people)
          Padding(
            padding: EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Expanded(child: Text(name(person), style: TextStyle(fontWeight: FontWeight.w800, color: StubColors.ink))),
                SizedBox(
                  width: 110,
                  child: TextField(
                    key: Key('value-$person'),
                    controller: _valueOf(person),
                    textAlign: TextAlign.right,
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      isDense: true,
                      prefixText: _method == SplitMethod.exact ? '₹ ' : null,
                      suffixText: _method == SplitMethod.percent ? '%' : null,
                    ),
                    onChanged: (_) => setState(() => _error = null),
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
          color: bad ? Color(0xFFFBEDEA) : Color(0xFFEEF6F1),
          borderRadius: BorderRadius.circular(StubRadius.control),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final line in summary)
              Text(
                line,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: bad ? StubColors.owe : StubColors.ink),
              ),
          ],
        ),
      ),
    ];
  }
}
