/// Bill splitting, in whole paise. Pure functions so they are easy to test.
library;

enum SplitMethod { equal, exact, percent, shares }

class SplitResult {
  const SplitResult.ok(this.shares) : problem = null;
  const SplitResult.invalid(this.problem) : shares = const {};

  /// What each person's part of the bill is, in paise. Empty when invalid.
  final Map<String, int> shares;

  /// A short, human reason the split cannot be saved yet, or null when fine.
  final String? problem;

  bool get ok => problem == null;
}

/// Works out each person's share of [total] paise.
///
/// [people] is everyone in the split, with the app's user first; any paise
/// left over from rounding go to the people at the front of the list.
/// [values] holds one number per person for the unequal methods: paise for
/// [SplitMethod.exact], percent for [SplitMethod.percent], and weights for
/// [SplitMethod.shares].
SplitResult computeShares({
  required int total,
  required List<String> people,
  required SplitMethod method,
  Map<String, num> values = const {},
}) {
  if (total <= 0) return const SplitResult.invalid('Enter an amount');
  if (people.isEmpty) return const SplitResult.invalid('Pick who is splitting');
  num valueOf(String person) => values[person] ?? 0;

  switch (method) {
    case SplitMethod.equal:
      return SplitResult.ok(
        _byWeights(total, people, {for (final p in people) p: 1}),
      );

    case SplitMethod.exact:
      final shares = {for (final p in people) p: valueOf(p).round()};
      final assigned = shares.values.fold<int>(0, (a, b) => a + b);
      if (assigned < total) {
        return SplitResult.invalid('${total - assigned} paise left to assign');
      }
      if (assigned > total) {
        return SplitResult.invalid('${assigned - total} paise too much');
      }
      return SplitResult.ok(shares);

    case SplitMethod.percent:
      final percent = people.fold<num>(0, (a, p) => a + valueOf(p));
      if ((percent - 100).abs() > 0.0001) {
        return SplitResult.invalid(
          percent < 100 ? 'Percentages add up to less than 100' : 'Percentages add up to more than 100',
        );
      }
      return SplitResult.ok(
        _byWeights(total, people, {for (final p in people) p: valueOf(p)}),
      );

    case SplitMethod.shares:
      final weight = people.fold<num>(0, (a, p) => a + valueOf(p));
      if (weight <= 0) {
        return const SplitResult.invalid('Give at least one share');
      }
      return SplitResult.ok(
        _byWeights(total, people, {for (final p in people) p: valueOf(p)}),
      );
  }
}

/// Splits [total] in proportion to [weights], rounding down, then hands the
/// leftover paise out one at a time in list order so the parts always add up.
Map<String, int> _byWeights(
  int total,
  List<String> people,
  Map<String, num> weights,
) {
  final sum = weights.values.fold<num>(0, (a, b) => a + b);
  final shares = {
    for (final p in people) p: (total * (weights[p] ?? 0) / sum).floor(),
  };
  var leftover = total - shares.values.fold<int>(0, (a, b) => a + b);
  for (final p in people) {
    if (leftover <= 0) break;
    if ((weights[p] ?? 0) > 0) {
      shares[p] = shares[p]! + 1;
      leftover -= 1;
    }
  }
  return shares;
}

/// One person owing another after a split.
class Debt {
  const Debt({required this.from, required this.to, required this.paise});

  final String from;
  final String to;
  final int paise;

  @override
  bool operator ==(Object other) =>
      other is Debt && other.from == from && other.to == to && other.paise == paise;

  @override
  int get hashCode => Object.hash(from, to, paise);

  @override
  String toString() => '$from owes $to $paise';
}

/// Who owes whom once [payer] has paid the whole bill.
List<Debt> debtsFor({required String payer, required Map<String, int> shares}) {
  return [
    for (final entry in shares.entries)
      if (entry.key != payer && entry.value > 0)
        Debt(from: entry.key, to: payer, paise: entry.value),
  ];
}
