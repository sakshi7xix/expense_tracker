import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stub/app.dart';
import 'package:stub/app_model.dart';
import 'package:stub/data/auth.dart';
import 'package:stub/data/db.dart';
import 'package:stub/data/store.dart';

import 'fake_auth.dart';

AppModel modelWith(Auth auth) {
  final store = StubStore(openMemoryDb())
    ..budget = 1500000
    ..firstRunDone = true;
  return AppModel(store, clock: () => DateTime(2026, 11, 25, 10), auth: auth);
}

Future<void> openSettings(WidgetTester tester, AppModel model) async {
  await tester.pumpWidget(StubApp(model: model));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('open-settings')));
  await tester.pumpAndSettle();
}

String profileName(WidgetTester tester) => tester.widget<Text>(find.byKey(const Key('profile-name'))).data!;

void main() {
  test('email and name checks', () {
    expect(looksLikeEmail(' asha@example.com '), isTrue);
    expect(looksLikeEmail('asha@example'), isFalse);
    expect(looksLikeEmail('asha example.com'), isFalse);
    expect(cleanName('  Asha   Rao '), 'Asha Rao');
    expect(cleanName('   '), isNull);
    expect(cleanName('x' * 61), isNull);
  });

  testWidgets('signing in: email, code, then your name', (tester) async {
    final auth = FakeAuth();
    final model = modelWith(auth);
    await openSettings(tester, model);
    expect(profileName(tester), 'Not signed in');

    await tester.tap(find.byKey(const Key('settings-sign-in')));
    await tester.pumpAndSettle();
    expect(find.text('Split with friends'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('signin-email')), 'asha@example');
    await tester.tap(find.byKey(const Key('signin-send')));
    await tester.pump();
    expect(find.text('That email doesn’t look right'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('signin-email')), 'asha@example.com');
    await tester.tap(find.byKey(const Key('signin-send')));
    await tester.pumpAndSettle();
    expect(auth.sentTo, 'asha@example.com');
    expect(find.text('Send again in 0:60'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('signin-code')), '000000');
    await tester.pumpAndSettle();
    expect(find.textContaining('wrong or has expired'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('signin-code')), '123456');
    await tester.pumpAndSettle();
    expect(find.text('Nice to meet you'), findsOneWidget);

    await tester.tap(find.byKey(const Key('signin-create')));
    await tester.pump();
    expect(find.text('Add your name'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('signin-name')), 'Asha');
    await tester.tap(find.byKey(const Key('signin-create')));
    await tester.pumpAndSettle();

    expect(model.auth.account?.name, 'Asha');
    expect(profileName(tester), 'Asha');
    await tester.scrollUntilVisible(find.byKey(const Key('delete-account')), 200);
    expect(find.byKey(const Key('delete-account')), findsOneWidget);
  });

  testWidgets('deleting the account signs out and keeps the phone data', (tester) async {
    final auth = FakeAuth(signedIn: const Account(id: 'u1', email: 'asha@example.com', name: 'Asha'));
    final model = modelWith(auth);
    await openSettings(tester, model);
    expect(profileName(tester), 'Asha');

    await tester.scrollUntilVisible(find.byKey(const Key('delete-account')), 200);
    await tester.tap(find.byKey(const Key('delete-account')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-delete')));
    await tester.pumpAndSettle();

    expect(auth.deleted, isTrue);
    expect(profileName(tester), 'Not signed in');
    expect(find.text('Your account was deleted'), findsOneWidget);
    expect(model.store.budget, 1500000);
  });

  testWidgets('the budget can be changed in Settings', (tester) async {
    final model = modelWith(OfflineAuth());
    await openSettings(tester, model);
    expect(find.byKey(const Key('settings-sign-in')), findsNothing, reason: 'no online service, no sign-in button');

    await tester.tap(find.byKey(const Key('edit-budget')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('budget-input')), '20000');
    await tester.tap(find.byKey(const Key('budget-save')));
    await tester.pumpAndSettle();
    expect(model.store.budget, 2000000);
    expect(find.text('₹20,000'), findsOneWidget);
  });

  testWidgets('the privacy policy says what stays on the phone', (tester) async {
    await openSettings(tester, modelWith(OfflineAuth()));
    await tester.tap(find.byKey(const Key('open-privacy')));
    await tester.pumpAndSettle();
    expect(find.textContaining('stay on your phone'), findsOneWidget);
  });

  testWidgets('Friends offers sign-in when signed out', (tester) async {
    final model = modelWith(FakeAuth());
    await tester.pumpWidget(StubApp(model: model));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nav-friends')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('friends-sign-in')));
    await tester.pumpAndSettle();
    expect(find.text('Split with friends'), findsOneWidget);
    await tester.tap(find.byKey(const Key('signin-later')));
    await tester.pumpAndSettle();
    expect(find.text('Split with friends'), findsNothing);
  });

  testWidgets('a returning person skips About you', (tester) async {
    final auth = FakeAuth()..names['asha@example.com'] = 'Asha';
    final model = modelWith(auth);
    await openSettings(tester, model);
    await tester.tap(find.byKey(const Key('settings-sign-in')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('signin-email')), 'asha@example.com');
    await tester.tap(find.byKey(const Key('signin-send')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('signin-code')), '123456');
    await tester.pumpAndSettle();
    expect(profileName(tester), 'Asha');
  });
}
