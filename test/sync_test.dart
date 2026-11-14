import 'package:flutter_test/flutter_test.dart';
import 'package:stub/data/db.dart';
import 'package:stub/data/remote.dart';
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
      ..addUser('A', 'asha@example.com', 'Asha', code: 'ASHA2345')
      ..addUser('B', 'bina@example.com', 'Bina', code: 'BINA6789');
    asha = StubStore(openMemoryDb());
    bina = StubStore(openMemoryDb());
    ashaSync = Sync(store: asha, remote: FakeRemote(server, 'A'), me: 'A', onChanged: () {});
    binaSync = Sync(store: bina, remote: FakeRemote(server, 'B'), me: 'B', onChanged: () {});
  });

  int food(StubStore s) => s.categories().first.id;

  Future<void> befriend() async {
    await ashaSync.request('bina 6789');
    await binaSync.run();
    await binaSync.answer(binaSync.requests.single, 'accepted');
    await ashaSync.run();
  }

  test('a friend is added with their code and appears once they accept', () async {
    await ashaSync.run();
    expect(ashaSync.myCode, 'ASHA2345');

    expect(await ashaSync.request('bina-6789'), 'Bina');
    expect(asha.friends(), isEmpty, reason: 'nobody is added until they accept');
    expect(ashaSync.waiting.single.toName, 'Bina');

    await binaSync.run();
    expect(binaSync.requests.single.fromName, 'Asha');
    await binaSync.answer(binaSync.requests.single, 'accepted');
    expect(bina.friends().single.name, 'Asha');

    await ashaSync.run();
    expect(asha.friends().single.name, 'Bina');
    expect(asha.userOfFriend(asha.friends().single.id), 'B');
    expect(ashaSync.waiting, isEmpty);
    expect(asha.notices().first.title, 'Bina accepted your request');
  });

  test('wrong codes are explained', () async {
    expect(() => ashaSync.request('NOPE0000'), throwsA(isA<RemoteFailure>()));
    expect(() => ashaSync.request('ASHA2345'), throwsA(isA<RemoteFailure>()));
    await befriend();
    expect(() => ashaSync.request('BINA6789'), throwsA(isA<RemoteFailure>()));
  });

  test('adding someone who already asked you makes you friends at once', () async {
    await binaSync.request('ASHA2345');
    final name = await ashaSync.request('BINA6789');
    expect(name, 'Bina');
    expect(asha.friends().single.name, 'Bina');
    await binaSync.run();
    expect(bina.friends().single.name, 'Asha');
  });

  test('splits and payments travel between friends, and deletions too', () async {
    await befriend();
    final binaOnAsha = asha.friends().single.id;
    final dinner = asha.addSpend(title: 'Dinner', total: 90000, categoryId: food(asha), day: nov25, friendShares: {binaOnAsha: 45000});
    await ashaSync.run();
    await binaSync.run();
    final ashaOnBina = bina.friendIdForUser('A')!;
    expect(bina.balanceOf(ashaOnBina), -45000);
    expect(bina.notices().first.title, 'Asha added “Dinner”');

    bina.settle(ashaOnBina, 20000, day: nov25);
    await binaSync.run();
    await ashaSync.run();
    expect(asha.balanceOf(binaOnAsha), 25000);
    expect(asha.notices().first.title, 'Bina paid you ₹200');

    asha.deleteSpend(dinner);
    await ashaSync.run();
    await binaSync.run();
    expect(bina.entriesForMonth(nov25), isEmpty);
  });

  test('editing a shared spend updates it on the friend’s phone, and un-splitting takes it down', () async {
    await befriend();
    final binaOnAsha = asha.friends().single.id;
    final id = asha.addSpend(title: 'Pizza', total: 60000, categoryId: food(asha), day: nov25, friendShares: {binaOnAsha: 30000});
    await ashaSync.run();
    await binaSync.run();
    final ashaOnBina = bina.friendIdForUser('A')!;
    expect(bina.balanceOf(ashaOnBina), -30000);

    asha.updateSpend(id, title: 'Pizza and drinks', total: 80000, categoryId: food(asha), friendShares: {binaOnAsha: 40000});
    await ashaSync.run();
    await binaSync.run();
    expect(bina.balanceOf(ashaOnBina), -40000);
    expect(bina.entriesForMonth(nov25).single.title, 'Pizza and drinks');

    asha.updateSpend(id, title: 'Pizza and drinks', total: 80000, categoryId: food(asha));
    await ashaSync.run();
    await binaSync.run();
    expect(bina.entriesForMonth(nov25), isEmpty);
    expect(bina.balanceOf(ashaOnBina), 0);
  });

  test('a friend added by name before codes is linked when they accept', () async {
    final old = asha.addFriend('Bina');
    asha.addSpend(title: 'Cab', total: 30000, categoryId: food(asha), day: nov25, friendShares: {old: 15000});
    await befriend();
    expect(asha.friends().single.id, old, reason: 'the same friend, now linked');
    await binaSync.run();
    expect(bina.entriesForMonth(nov25).single.title, 'Cab', reason: 'older splits reach them too');
  });

  test('a phone with another account’s data does not sync', () async {
    asha.accountId = 'someone-else';
    await ashaSync.run();
    expect(ashaSync.blocked, isTrue);
  });
}
