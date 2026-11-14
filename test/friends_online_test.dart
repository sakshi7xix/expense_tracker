import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stub/app.dart';
import 'package:stub/app_model.dart';
import 'package:stub/data/auth.dart';
import 'package:stub/data/db.dart';
import 'package:stub/data/store.dart';

import 'fake_auth.dart';
import 'fake_remote.dart';

void main() {
  late FakeServer server;

  AppModel ashaPhone() {
    final store = StubStore(openMemoryDb())
      ..budget = 1500000
      ..firstRunDone = true;
    return AppModel(
      store,
      clock: () => DateTime(2026, 11, 25, 10),
      auth: FakeAuth(signedIn: const Account(id: 'A', email: 'asha@example.com', name: 'Asha')),
      remoteFor: (id) => FakeRemote(server, id),
    );
  }

  setUp(() {
    server = FakeServer()
      ..addUser('A', 'asha@example.com', 'Asha')
      ..addUser('K', 'kabir@example.com', 'Kabir');
  });

  testWidgets('a friend request shows on the bell and can be accepted', (tester) async {
    await FakeRemote(server, 'K').createInvite('Asha', 'asha@example.com');
    final model = ashaPhone();
    await tester.pumpWidget(StubApp(model: model));
    await tester.pumpAndSettle();

    expect(find.descendant(of: find.byKey(const Key('bell-count')), matching: find.text('1')), findsOneWidget);
    await tester.tap(find.byKey(const Key('bell')));
    await tester.pumpAndSettle();
    expect(find.text('Kabir wants to add you'), findsOneWidget);
    expect(find.text('kab•••@example.com'), findsOneWidget);

    await tester.tap(find.byKey(Key('accept-${server.invites.keys.single}')));
    await tester.pumpAndSettle();
    expect(model.store.friends().single.name, 'Kabir');
    expect(server.friends('A', 'K'), isTrue);
    expect(find.text('You and Kabir are friends now'), findsOneWidget);
  });

  testWidgets('"I don\'t know them" removes the request', (tester) async {
    await FakeRemote(server, 'K').createInvite('Asha', 'asha@example.com');
    final model = ashaPhone();
    await tester.pumpWidget(StubApp(model: model));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('bell')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('block-${server.invites.keys.single}')));
    await tester.pumpAndSettle();
    expect(find.text('Kabir wants to add you'), findsNothing);
    expect(server.invites.values.single['status'], 'blocked');
    expect(model.store.friends(), isEmpty);
  });

  testWidgets('an invite code finds the friend who sent it', (tester) async {
    final made = await FakeRemote(server, 'K').createInvite('Asha', null);
    final model = ashaPhone();
    await tester.pumpWidget(StubApp(model: model));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('bell-count')), findsNothing);

    await tester.tap(find.byKey(const Key('bell')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('invite-code')), made.code);
    await tester.tap(find.byKey(const Key('invite-code-find')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('accept-${made.id}')));
    await tester.pumpAndSettle();
    expect(model.store.friends().single.name, 'Kabir');
  });

  testWidgets('a split a friend added can only be changed by them', (tester) async {
    server.friendships.add('A|K');
    await FakeRemote(server, 'K').saveExpense(
      id: 'x1', title: 'Cab home', total: 40000, payer: 'K', day: '2026-11-25', shares: {'A': 20000, 'K': 20000});
    final model = ashaPhone();
    await tester.pumpWidget(StubApp(model: model));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cab home'));
    await tester.pumpAndSettle();
    expect(find.text('Added by Kabir. Only they can change it.'), findsOneWidget);
    expect(find.byKey(const Key('receipt-delete')), findsNothing);
  });
}
