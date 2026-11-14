import 'package:flutter_test/flutter_test.dart';
import 'package:stub/data/db.dart';
import 'package:stub/data/models.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:stub/data/store.dart';

void main() {
  late StubStore store;
  late int food, shop;
  final nov = DateTime(2026, 11, 1);
  final nov25 = DateTime(2026, 11, 25);

  setUp(() {
    store = StubStore(openMemoryDb());
    final cats = {for (final c in store.categories()) c.name: c.id};
    food = cats['Food']!;
    shop = cats['Shopping']!;
  });

  tearDown(() => store.db.close());

  test('starts with default categories and no budget', () {
    expect(store.categories().map((c) => c.name), defaultCategories);
    expect(store.budget, 0);
    expect(store.firstRunDone, isFalse);
  });

  test('an existing phone gets the Investments category on upgrade', () {
    final db = openMemoryDb();
    db.execute("DELETE FROM category WHERE name = 'Investments'");
    db.userVersion = 5;
    migrate(db);
    final names = StubStore(db).categories().map((c) => c.name).toList();
    expect(names, defaultCategories);
    expect(names[names.length - 2], 'Investments', reason: 'just before Other');
    db.close();
  });

  test('settings persist', () {
    store.budget = 1500000;
    store.firstRunDone = true;
    expect(store.budget, 1500000);
    expect(store.firstRunDone, isTrue);
  });

  group('spends', () {
    test('totals by month, day and category', () {
      store.addSpend(title: 'Groceries', total: 32650, categoryId: food, day: nov25);
      store.addSpend(title: 'Chai', total: 2000, categoryId: shop, day: nov25);
      store.addSpend(title: 'Lunch', total: 14000, categoryId: food, day: DateTime(2026, 11, 22));
      store.addSpend(title: 'October', total: 9900, categoryId: food, day: DateTime(2026, 10, 30));

      expect(store.spentInMonth(nov), 48650);
      expect(store.spentOnDay(nov25), 34650);
      expect(store.categoryTotals(nov), {food: 46650, shop: 2000});
      expect(store.entriesForMonth(nov).map((e) => e.title), ['Chai', 'Groceries', 'Lunch']);
      final daily = store.dailyTotals(nov);
      expect(daily.length, 30);
      expect(daily[24], 34650);
      expect(daily[21], 14000);
    });

    test('delete is soft and can be undone', () {
      final id = store.addSpend(title: 'Chai', total: 2000, categoryId: shop, day: nov25);
      store.deleteSpend(id);
      expect(store.spentInMonth(nov), 0);
      store.restoreSpend(id);
      expect(store.spentInMonth(nov), 2000);
    });

    test('rejects shares bigger than the bill', () {
      final riya = store.addFriend('Riya');
      expect(
        () => store.addSpend(title: 'x', total: 1000, categoryId: food, day: nov25, friendShares: {riya: 2000}),
        throwsArgumentError,
      );
    });
  });

  group('splits and friends', () {
    late int riya, aman;
    setUp(() {
      riya = store.addFriend('Riya', contact: 'riya@example.com');
      aman = store.addFriend('Aman');
    });

    test('when you pay, friends owe their shares and only yours hits the budget', () {
      final id = store.addSpend(
        title: 'Dinner',
        total: 12000,
        categoryId: food,
        day: nov25,
        friendShares: {riya: 4000, aman: 4000},
      );
      expect(store.spentInMonth(nov), 4000);
      expect(store.entriesForDay(nov25).single.isSplit, isTrue);
      expect(store.balanceOf(riya), 4000);
      expect(store.owedToYou, 8000);
      expect(store.youOwe, 0);

      store.deleteSpend(id);
      expect(store.owedToYou, 0);
    });

    test('when a friend pays, you owe them your share', () {
      store.addSpend(
        title: 'Cab',
        total: 9000,
        categoryId: food,
        day: nov25,
        friendShares: {riya: 3000, aman: 3000},
        payerFriendId: riya,
      );
      expect(store.spentInMonth(nov), 3000);
      expect(store.balanceOf(riya), -3000);
      expect(store.balanceOf(aman), 0);
      expect(store.youOwe, 3000);
    });

    test('settle up in part, then in full, never past zero', () {
      store.addSpend(title: 'Dinner', total: 12000, categoryId: food, day: nov25, friendShares: {riya: 6000});
      expect(store.settle(riya, 2500, day: nov25), 2500);
      expect(store.balanceOf(riya), 3500);
      expect(store.settle(riya, 99999, day: nov25), 3500);
      expect(store.balanceOf(riya), 0);
      expect(store.settle(riya, 100, day: nov25), 0);

      final history = store.activity(friendId: riya);
      expect(history.length, 3);
      expect(history.where((i) => i.isPayment).length, 2);
    });

    test('names are unique ignoring case', () {
      expect(() => store.addFriend('riya'), throwsStateError);
      expect(() => store.addFriend('  '), throwsArgumentError);
    });

    test('groups keep their members', () {
      final id = store.addGroup('Flatmates', [riya, aman, riya]);
      final group = store.groups().single;
      expect(group.id, id);
      expect(group.name, 'Flatmates');
      expect(group.memberIds, [riya, aman]);
    });

    test('a group adds up its own spends and balances', () {
      final flat = store.addGroup('Flatmates', [riya, aman]);
      store.addSpend(title: 'Groceries', total: 90000, categoryId: food, day: nov25, friendShares: {riya: 30000, aman: 30000}, groupId: flat);
      store.addSpend(title: 'Gas', total: 60000, categoryId: food, day: nov25, friendShares: {riya: 20000, aman: 20000}, payerFriendId: aman, groupId: flat);
      store.addSpend(title: 'Movie', total: 50000, categoryId: food, day: nov25, friendShares: {riya: 25000});

      final summary = store.groupSummary(flat);
      expect(summary.spent, 150000);
      expect(summary.balances, {riya: 30000, aman: 10000});
      expect(summary.balance, 40000);
      expect(store.groupEntries(flat).map((e) => e.title), ['Gas', 'Groceries']);
      expect(store.balanceOf(riya), 55000, reason: 'the movie is outside the group');

      store.addGroupMembers(flat, [riya]);
      expect(store.groups().single.memberIds, [riya, aman]);
      store.removeGroup(flat);
      expect(store.groups(), isEmpty);
    });
  });

  group('bills and autopay', () {
    test('autopays log themselves once their day has come', () {
      final wifi = store.addBill(name: 'Wi-Fi', amount: 69900, dueDay: 28, categoryId: food, autopay: true);
      store.addBill(name: 'Netflix', amount: 19900, dueDay: 12, categoryId: food, autopay: true);
      store.addBill(name: 'Electricity', amount: 64000, dueDay: 27, categoryId: food);

      expect(store.committedFor(nov), 153800);
      expect(store.runAutopays(nov25).length, 1);
      expect(store.runAutopays(nov25), isEmpty, reason: 'running twice must not double charge');

      final netflix = store.entriesForMonth(nov).single;
      expect(netflix.title, 'Netflix');
      expect(netflix.day, '2026-11-12');
      expect(netflix.isAutopay, isTrue);
      expect(store.committedFor(nov), 133900);

      expect(store.runAutopays(DateTime(2026, 11, 28)).length, 1);
      expect(store.billsFor(nov).firstWhere((b) => b.id == wifi).state, BillState.paid);
      expect(store.spentInMonth(nov), 89800);
    });

    test('a new month charges again', () {
      store.addBill(name: 'Netflix', amount: 19900, dueDay: 12, categoryId: food, autopay: true);
      store.runAutopays(nov25);
      expect(store.runAutopays(DateTime(2026, 12, 12)).length, 1);
      expect(store.spentInMonth(DateTime(2026, 12, 1)), 19900);
    });

    test('skipped and manual bills are never auto-charged', () {
      final gym = store.addBill(name: 'Gym', amount: 100000, dueDay: 5, categoryId: food, autopay: true);
      final power = store.addBill(name: 'Electricity', amount: 64000, dueDay: 10, categoryId: food);
      store.skipBill(gym, month: nov);
      expect(store.runAutopays(nov25), isEmpty);
      expect(store.billsFor(nov).firstWhere((b) => b.id == gym).state, BillState.skipped);

      expect(store.payBill(power, day: nov25), isNotNull);
      expect(store.payBill(power, day: nov25), isNull);
      expect(store.spentInMonth(nov), 64000);
    });

    test('a paid bill can be unticked, which removes its spend', () {
      final power = store.addBill(name: 'Electricity', amount: 64000, dueDay: 27, categoryId: food);
      store.payBill(power, day: nov25);
      expect(store.spentInMonth(nov), 64000);
      store.unpayBill(power, month: nov);
      expect(store.spentInMonth(nov), 0);
      expect(store.billsFor(nov).single.state, BillState.due);
      expect(store.payBill(power, day: nov25), isNotNull, reason: 'it can be paid again');
    });

    test('a spend knows who it was split with', () {
      final riya = store.addFriend('Riya');
      final id = store.addSpend(title: 'Chai', total: 4000, categoryId: food, day: nov25, friendShares: {riya: 2000});
      expect(store.splitOf(id), {'Riya': 2000});
      expect(store.entry(id)!.amount, 2000);
      store.deleteSpend(id);
      expect(store.entry(id), isNull);
    });

    test('editing a split spend changes the amount and everyone\'s share', () {
      final riya = store.addFriend('Riya');
      final id = store.addSpend(title: 'Dinner', total: 12000, categoryId: food, day: nov25, friendShares: {riya: 6000});
      store.updateSpend(id, title: 'Dinner out', total: 20000, categoryId: shop, friendShares: {riya: 10000});
      final e = store.entriesForMonth(nov).single;
      expect((e.title, e.total, e.amount, e.categoryId), ('Dinner out', 20000, 10000, shop));
      expect(store.balanceOf(riya), 10000);
      expect(store.splitOfSpend(id).shares, {riya: 10000});
      expect(store.splitOfSpend(id).payer, isNull);

      store.updateSpend(id, title: 'Dinner out', total: 20000, categoryId: shop);
      expect(store.balanceOf(riya), 0, reason: 'no longer split');
      expect(store.spentInMonth(nov), 20000);
    });

    test('a bill due on the 31st is charged on the last day of a short month', () {
      store.addBill(name: 'Rent', amount: 280000, dueDay: 31, categoryId: food, autopay: true);
      expect(store.runAutopays(DateTime(2026, 11, 29)), isEmpty);
      store.runAutopays(DateTime(2026, 11, 30));
      expect(store.entriesForMonth(nov).single.day, '2026-11-30');
    });
  });

  test('an older database is moved to the refined categories without losing spends', () {
    final db = sqlite3InMemoryV1();
    final old = {for (final r in db.select('SELECT id, name FROM category')) r['name'] as String: r['id'] as int};
    db.execute(
      "INSERT INTO entry (title, amount, total, category_id, day, created_at) VALUES ('Chai', 2000, 2000, ?, '2026-11-25', 0)",
      [old['Café']],
    );
    db.execute(
      "INSERT INTO entry (title, amount, total, category_id, day, created_at) VALUES ('Bus', 3000, 3000, ?, '2026-11-25', 0)",
      [old['Travel']],
    );
    migrate(db);
    final upgraded = StubStore(db);
    final names = {for (final c in upgraded.categories()) c.id: c.name};
    expect(names.values, defaultCategories);
    final byTitle = {for (final e in upgraded.entriesForMonth(DateTime(2026, 11))) e.title: names[e.categoryId]};
    expect(byTitle, {'Chai': 'Food', 'Bus': 'Transport'});
    db.close();
  });
}

/// A database as the first release created it: schema v1 with six categories.
Database sqlite3InMemoryV1() {
  final db = openMemoryDb();
  db.execute('DELETE FROM category');
  const v1 = ['Food', 'Café', 'Travel', 'Fun', 'Home', 'Study'];
  for (var i = 0; i < v1.length; i++) {
    db.execute('INSERT INTO category (name, sort) VALUES (?, ?)', [v1[i], i]);
  }
  db.userVersion = 1;
  return db;
}
