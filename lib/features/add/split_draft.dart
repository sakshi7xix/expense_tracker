import '../../core/money.dart';
import '../../core/split.dart';

/// The key used for the app's user inside a split.
const me = 'me';

/// The split being set up for one spend, before it is saved.
class SplitDraft {
  final friends = <int>{};

  /// Friend who paid the bill, or null when you paid.
  int? payer;
  SplitMethod method = SplitMethod.equal;

  /// What was typed per person for the unequal methods.
  final values = <String, String>{};

  /// The group this spend is for, if one was picked.
  int? groupId;
  String groupName = '';
  final _groupMembers = <int>{};

  bool get active => friends.isNotEmpty;

  /// Fills the draft from a saved spend: equal if the shares are even,
  /// otherwise the exact amounts.
  void load(Map<int, int> shares, int? payerFriendId, int total) {
    clear();
    friends.addAll(shares.keys);
    payer = payerFriendId;
    final mine = total - shares.values.fold<int>(0, (a, b) => a + b);
    final even = computeShares(total: total, people: people, method: SplitMethod.equal);
    final isEven = even.ok && people.every((p) => even.shares[p] == (p == me ? mine : shares[int.parse(p)]));
    if (isEven) return;
    method = SplitMethod.exact;
    values[me] = (mine / 100).toStringAsFixed(2);
    shares.forEach((id, share) => values['$id'] = (share / 100).toStringAsFixed(2));
  }

  List<String> get people => [me, for (final id in friends) '$id'];

  void clear() {
    friends.clear();
    values.clear();
    payer = null;
    method = SplitMethod.equal;
    groupId = null;
    groupName = '';
    _groupMembers.clear();
  }

  /// Splits with everyone in a group, or un-picks it if it was picked.
  void useGroup(int id, String name, List<int> members, int total) {
    final again = groupId == id;
    clear();
    if (again) return;
    groupId = id;
    groupName = name;
    _groupMembers.addAll(members);
    friends.addAll(members);
    prefill(total);
  }

  void toggle(int friendId, int total) {
    friends.contains(friendId) ? friends.remove(friendId) : friends.add(friendId);
    // Adding someone from outside the group makes it an ordinary split.
    if (!_groupMembers.containsAll(friends)) {
      groupId = null;
      groupName = '';
      _groupMembers.clear();
    }
    if (payer != null && !friends.contains(payer)) payer = null;
    prefill(total);
  }

  /// Drops friends that no longer exist.
  void prune(Set<int> existing) {
    friends.removeWhere((id) => !existing.contains(id));
    if (friends.isEmpty) groupId = null;
    if (payer != null && !friends.contains(payer)) payer = null;
  }

  /// Starting numbers for the unequal methods: an even split.
  void prefill(int total) {
    values.clear();
    final everyone = people;
    final even = computeShares(total: total, people: everyone, method: SplitMethod.equal);
    final basePercent = 100 ~/ everyone.length;
    for (final person in everyone) {
      values[person] = switch (method) {
        SplitMethod.equal => '',
        SplitMethod.exact => even.ok ? (even.shares[person]! / 100).toStringAsFixed(2) : '',
        SplitMethod.percent =>
          person == me ? '${100 - basePercent * (everyone.length - 1)}' : '$basePercent',
        SplitMethod.shares => '1',
      };
    }
  }

  num _read(String person) {
    final text = values[person] ?? '';
    return method == SplitMethod.exact ? (parseAmount(text) ?? 0) : (double.tryParse(text) ?? 0);
  }

  SplitResult result(int total) {
    return computeShares(
      total: total,
      people: people,
      method: method,
      values: {for (final p in people) p: _read(p)},
    );
  }

  /// Why the split cannot be saved, in rupees rather than paise.
  String problem(int total, SplitResult result) {
    if (method != SplitMethod.exact) return result.problem ?? '';
    final assigned = people.fold<int>(0, (a, p) => a + (parseAmount(values[p] ?? '') ?? 0));
    final gap = total - assigned;
    return gap > 0
        ? '${formatInr(gap, decimals: true)} left to assign'
        : '${formatInr(-gap, decimals: true)} too much';
  }

  /// "Riya owes you ₹60.00" style lines for a valid split.
  List<String> debtLines(SplitResult result, Map<int, String> names) {
    String name(String person) => person == me ? 'You' : names[int.parse(person)] ?? '';
    return [
      for (final debt in debtsFor(payer: payer == null ? me : '$payer', shares: result.shares))
        debt.from == me
            ? 'You owe ${name(debt.to)} ${formatInr(debt.paise, decimals: true)}'
            : debt.to == me
                ? '${name(debt.from)} owes you ${formatInr(debt.paise, decimals: true)}'
                : '${name(debt.from)} owes ${name(debt.to)} ${formatInr(debt.paise, decimals: true)}',
    ];
  }

  /// One line for the form row, e.g. "With Riya, Aman · Riya paid".
  String label(Map<int, String> names) {
    if (!active) return 'Just me';
    final who = groupId != null ? groupName : [for (final id in friends) names[id] ?? ''].join(', ');
    return payer == null ? 'With $who' : 'With $who · ${names[payer]} paid';
  }
}
