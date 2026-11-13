import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stub/app.dart';
import 'package:stub/app_model.dart';
import 'package:stub/data/db.dart';
import 'package:stub/data/store.dart';

AppModel newModel() {
  return AppModel(StubStore(openMemoryDb()), clock: () => DateTime(2026, 11, 25, 10));
}

String leftAmount(WidgetTester tester) {
  return tester.widget<Text>(find.byKey(const Key('left-amount'))).data!;
}

Future<void> start(WidgetTester tester, AppModel model) async {
  await tester.pumpWidget(StubApp(model: model));
  await tester.enterText(find.byKey(const Key('budget-field')), '15000');
  await tester.tap(find.text('Start'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('first run asks for a budget, then opens Home', (tester) async {
    final model = newModel();
    await tester.pumpWidget(StubApp(model: model));
    expect(find.text('What can you spend in a month?'), findsOneWidget);

    await tester.tap(find.text('Start'));
    await tester.pump();
    expect(find.text('Type an amount, like 15000'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('budget-field')), '15000');
    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();
    expect(model.store.budget, 1500000);
    expect(leftAmount(tester), '₹15,000');
    expect(find.text('No spends yet. Tap + to add one.'), findsOneWidget);
  });

  testWidgets('adding a spend prints a stub and updates Home', (tester) async {
    final model = newModel();
    await start(tester, model);

    await tester.tap(find.byKey(const Key('fab-add')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('amount-field')), '120');
    await tester.enterText(find.byKey(const Key('title-field')), 'Chai with Riya');
    await tester.tap(find.byKey(const Key('save-button')));
    await tester.pumpAndSettle();
    expect(find.text('STUB'), findsOneWidget);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(model.store.spentInMonth(model.today), 12000);
    expect(leftAmount(tester), '₹14,880');
    expect(find.text('Chai with Riya'), findsOneWidget);
  });

  testWidgets('splitting with a friend only charges your share', (tester) async {
    final model = newModel();
    final riya = model.store.addFriend('Riya');
    await start(tester, model);

    await tester.tap(find.byKey(const Key('fab-add')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('amount-field')), '120');
    await tester.ensureVisible(find.byKey(Key('friend-$riya')));
    await tester.tap(find.byKey(Key('friend-$riya')));
    await tester.pumpAndSettle();
    expect(find.text('Riya owes you ₹60.00'), findsOneWidget);

    await tester.ensureVisible(find.byKey(Key('payer-$riya')));
    await tester.tap(find.byKey(Key('payer-$riya')));
    await tester.pumpAndSettle();
    expect(find.text('You owe Riya ₹60.00'), findsOneWidget);

    await tester.tap(find.byKey(const Key('payer-me')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(model.store.spentInMonth(model.today), 6000);
    expect(model.store.balanceOf(riya), 6000);
    expect(leftAmount(tester), '₹14,940');
  });

  testWidgets('Friends shows balances and records a part payment', (tester) async {
    final model = newModel();
    final riya = model.store.addFriend('Riya');
    final food = model.store.categories().first.id;
    model.store.addSpend(title: 'Dinner', total: 12000, categoryId: food, day: model.today, friendShares: {riya: 6000});
    await start(tester, model);

    await tester.tap(find.byKey(const Key('nav-friends')));
    await tester.pumpAndSettle();
    expect(find.text('owes you'), findsOneWidget);

    await tester.tap(find.byKey(Key('friend-row-$riya')));
    await tester.pumpAndSettle();
    expect(find.text('Riya owes you ₹60.00'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('settle-field')), '25');
    await tester.tap(find.byKey(const Key('settle-button')));
    await tester.pumpAndSettle();

    expect(model.store.balanceOf(riya), 3500);
    expect(find.text('₹35'), findsWidgets);
  });
}
