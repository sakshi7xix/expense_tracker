import 'package:flutter_test/flutter_test.dart';
import 'package:stub/data/db.dart';
import 'package:stub/data/store.dart';
import 'package:stub/data/sync.dart';

import 'fake_remote.dart';

void main() {
  late FakeServer server;
  late StubStore asha, bina;
  late Sync ashaSync, binaSync;
  final nov25 = DateTime(2026, 11, 25);

  setUp(() {
    server = FakeServer()
      ..addUser('A', 'asha@example.com', 'Asha')
      ..addUser('B', 'bina@example.com', 'Bina');
    asha = StubStore(openMemoryDb());
    bina = StubStore(openMemoryDb());
    ashaSync = Sync(store: asha, remote: FakeRemote(server, 'A'), me: 'A', onChanged: () {});
    binaSync = Sync(store: bina, remote: FakeRemote(server, 'B'), me: 'B', onChanged: () {});
  });

  int food(StubStore s) => s.categories().first.id;

  test('splits made before a friend joins reach them once they accept', () async {
    final binaOnAsha = asha.addFriend('Bina', contact: 'bina@example.com');
    asha.addSpend(title: 'Dinner', total: 120000, categoryId: food(asha), day: nov25, friendShares: {binaOnAsha: 60000});
    await ashaSync.run();
    expect(server.expenses, isEmpty, reason: 'nothing goes online until Bina joins');

    final code = await ashaSync.invite(binaOnAsha);
    expect(code, isNotEmpty);
    expect(asha.waitingInvites().single.name, 'Bina');

    await binaSync.run();
    expect(binaSync.requests.single.fromName, 'Asha');
    expect(binaSync.requests.single.fromEmail, 'ash•••@example.com');
    await binaSync.answer(binaSync.requests.single, 'accepted');

    await ashaSync.run();
    expect(asha.waitingInvites(), isEmpty);
    expect(asha.notices().first.title, 'Bina accepted your invite');
    expect(server.expenses.values.single.shares, {'A': 60000, 'B': 60000});

    await binaSync.run();
    final ashaOnBina = bina.friendIdForUser('A')!;
    expect(bina.balanceOf(ashaOnBina), -60000, reason: 'Bina owes Asha her share');
    final dinner = bina.entriesForMonth(nov25).single;
    expect((dinner.title, dinner.amount, dinner.total, dinner.addedBy), ('Dinner', 60000, 120000, 'A'));
    expect(bina.notices().first.title, 'Asha added “Dinner”');
    expect(bina.unseenNotices, 1);
  });

  test('payments and deletions travel both ways', () async {
    final binaOnAsha = asha.addFriend('Bina', contact: 'bina@example.com');
    await ashaSync.invite(binaOnAsha);
    await binaSync.run();
    await binaSync.answer(binaSync.requests.single, 'accepted');
    await ashaSync.run();

    final dinner = asha.addSpend(title: 'Dinner', total: 90000, categoryId: food(asha), day: nov25, friendShares: {binaOnAsha: 45000});
    await ashaSync.run();
    await binaSync.run();
    final ashaOnBina = bina.friendIdForUser('A')!;

    bina.settle(ashaOnBina, 20000, day: nov25);
    await binaSync.run();
    await ashaSync.run();
    expect(asha.balanceOf(binaOnAsha), 25000);
    expect(asha.notices().first.title, 'Bina paid you ₹200');

    asha.deleteSpend(dinner);
    await ashaSync.run();
    await binaSync.run();
    expect(bina.entriesForMonth(nov25), isEmpty);
    expect(bina.balanceOf(ashaOnBina), 20000, reason: 'only the payment is left');
  });

  test('a friend can be found by invite code, and a split with someone not on the app stays on the phone', () async {
    final binaOnAsha = asha.addFriend('Bina');
    final code = await ashaSync.invite(binaOnAsha);
    final found = await binaSync.findCode(code);
    expect(found!.fromName, 'Asha');
    await binaSync.answer(found, 'accepted');
    await ashaSync.run();
    expect(asha.userOfFriend(binaOnAsha), 'B');

    final chet = asha.addFriend('Chet');
    asha.addSpend(title: 'Cab', total: 30000, categoryId: food(asha), day: nov25, friendShares: {chet: 15000});
    await ashaSync.run();
    expect(server.expenses, isEmpty);
  });

  test('a phone with another account’s data does not sync', () async {
    asha.accountId = 'someone-else';
    await ashaSync.run();
    expect(ashaSync.blocked, isTrue);
  });
}
