import 'package:flutter_test/flutter_test.dart';
import 'package:stub/core/split.dart';

void main() {
  const people = ['You', 'Riya', 'Aman'];

  int sum(Map<String, int> shares) => shares.values.fold(0, (a, b) => a + b);

  group('equal', () {
    test('splits evenly', () {
      final r = computeShares(total: 12000, people: people, method: SplitMethod.equal);
      expect(r.ok, isTrue);
      expect(r.shares, {'You': 4000, 'Riya': 4000, 'Aman': 4000});
    });

    test('gives leftover paise to the front so it always adds up', () {
      final r = computeShares(total: 10000, people: people, method: SplitMethod.equal);
      expect(r.shares, {'You': 3334, 'Riya': 3333, 'Aman': 3333});
      expect(sum(r.shares), 10000);
    });
  });

  group('exact', () {
    test('accepts amounts that add up', () {
      final r = computeShares(
        total: 12000,
        people: people,
        method: SplitMethod.exact,
        values: {'You': 2000, 'Riya': 6000, 'Aman': 4000},
      );
      expect(r.ok, isTrue);
      expect(r.shares['Riya'], 6000);
    });

    test('rejects too little and too much', () {
      final low = computeShares(
        total: 12000,
        people: people,
        method: SplitMethod.exact,
        values: {'You': 2000, 'Riya': 6000},
      );
      expect(low.ok, isFalse);
      expect(low.problem, contains('left'));

      final high = computeShares(
        total: 12000,
        people: people,
        method: SplitMethod.exact,
        values: {'You': 4000, 'Riya': 6000, 'Aman': 4000},
      );
      expect(high.ok, isFalse);
      expect(high.problem, contains('too much'));
    });
  });

  group('percent', () {
    test('splits by percentage', () {
      final r = computeShares(
        total: 12000,
        people: people,
        method: SplitMethod.percent,
        values: {'You': 50, 'Riya': 25, 'Aman': 25},
      );
      expect(r.shares, {'You': 6000, 'Riya': 3000, 'Aman': 3000});
    });

    test('must add up to 100', () {
      final r = computeShares(
        total: 12000,
        people: people,
        method: SplitMethod.percent,
        values: {'You': 50, 'Riya': 25},
      );
      expect(r.ok, isFalse);
    });

    test('rounding never loses a paisa', () {
      final r = computeShares(
        total: 10001,
        people: people,
        method: SplitMethod.percent,
        values: {'You': 33.3, 'Riya': 33.3, 'Aman': 33.4},
      );
      expect(r.ok, isTrue);
      expect(sum(r.shares), 10001);
    });
  });

  group('shares', () {
    test('splits by weight', () {
      final r = computeShares(
        total: 12000,
        people: people,
        method: SplitMethod.shares,
        values: {'You': 2, 'Riya': 1, 'Aman': 1},
      );
      expect(r.shares, {'You': 6000, 'Riya': 3000, 'Aman': 3000});
    });

    test('needs at least one share', () {
      final r = computeShares(total: 12000, people: people, method: SplitMethod.shares);
      expect(r.ok, isFalse);
    });
  });

  test('invalid input is reported, not thrown', () {
    expect(computeShares(total: 0, people: people, method: SplitMethod.equal).ok, isFalse);
    expect(computeShares(total: 100, people: const [], method: SplitMethod.equal).ok, isFalse);
  });

  group('debtsFor', () {
    const shares = {'You': 2000, 'Riya': 6000, 'Aman': 4000};

    test('everyone else owes the payer their share', () {
      expect(debtsFor(payer: 'You', shares: shares), const [
        Debt(from: 'Riya', to: 'You', paise: 6000),
        Debt(from: 'Aman', to: 'You', paise: 4000),
      ]);
    });

    test('when a friend paid, you owe them your share', () {
      expect(debtsFor(payer: 'Riya', shares: shares), const [
        Debt(from: 'You', to: 'Riya', paise: 2000),
        Debt(from: 'Aman', to: 'Riya', paise: 4000),
      ]);
    });
  });
}
