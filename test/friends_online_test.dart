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

  AppModel ashaPhone({bool signedIn = true}) {
    final store = StubStore(openMemoryDb())
      ..budget = 1500000
      ..firstRunDone = true;
    return AppModel(
      store,
      clock: () => DateTime(2026, 11, 25, 10),
      auth: FakeAuth(signedIn: signedIn ? const Account(id: 'A', email: 'asha@example.com', name: 'Asha') : null),
      remoteFor: (id) => FakeRemote(server, id),
    );
  }

  setUp(() {
    server = FakeServer()
      ..addUser('A', 'asha@example.com', 'Asha', code: 'ASHA2345')
      ..addUser('K', 'kabir@example.com', 'Kabir', code: 'KABR6789');
  });

  Future<void> openAddFriend(WidgetTester tester, AppModel model) async {
    await tester.pumpWidget(StubApp(model: model));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nav-friends')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add-friend')));
    await tester.pumpAndSettle();
  }

  testWidgets('Add a friend shows your code and sends a request with theirs', (tester) async {
    final model = ashaPhone();
    await openAddFriend(tester, model);
    expect(tester.widget<Text>(find.byKey(const Key('my-code'))).data, 'ASHA 2345');

    await tester.enterText(find.byKey(const Key('friend-code-field')), 'abc');
    await tester.tap(find.byKey(const Key('friend-request')));
    await tester.pump();
    expect(find.text('A friend code has 8 letters and numbers'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('friend-code-field')), 'kabr 6789');
    await tester.tap(find.byKey(const Key('friend-request')));
    await tester.pumpAndSettle();
    expect(find.text('Request sent to Kabir'), findsOneWidget);
    expect(model.store.friends(), isEmpty, reason: 'Kabir joins the list when he accepts');
  });

  testWidgets('without signing in, Add a friend asks you to sign in', (tester) async {
    await openAddFriend(tester, ashaPhone(signedIn: false));
    expect(find.byKey(const Key('add-friend-sign-in')), findsOneWidget);
    expect(find.byKey(const Key('friend-code-field')), findsNothing);
  });

  testWidgets('a friend request shows on the bell and can be accepted', (tester) async {
    await FakeRemote(server, 'K').requestFriend('ASHA2345');
    final model = ashaPhone();
    await tester.pumpWidget(StubApp(model: model));
    await tester.pumpAndSettle();

    expect(find.descendant(of: find.byKey(const Key('bell-count')), matching: find.text('1')), findsOneWidget);
    await tester.tap(find.byKey(const Key('bell')));
    await tester.pumpAndSettle();
    expect(find.text('Kabir wants to add you'), findsOneWidget);

    await tester.tap(find.byKey(Key('accept-${server.invites.keys.single}')));
    await tester.pumpAndSettle();
    expect(model.store.friends().single.name, 'Kabir');
    expect(server.friends('A', 'K'), isTrue);
  });

  testWidgets('"I don\'t know them" removes the request', (tester) async {
    await FakeRemote(server, 'K').requestFriend('ASHA2345');
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

  testWidgets('your code is in Settings', (tester) async {
    await tester.pumpWidget(StubApp(model: ashaPhone()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-settings')));
    await tester.pumpAndSettle();
    expect(find.text('Your friend code: ASHA 2345'), findsOneWidget);
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
