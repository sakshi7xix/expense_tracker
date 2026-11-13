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
    expect(find.text('How much do you earn in a month?'), findsOneWidget);

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
    expect(find.text('Just me'), findsOneWidget);
    await tester.tap(find.byKey(const Key('split-row')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('friend-$riya')));
    await tester.pumpAndSettle();
    expect(find.text('Riya owes you ₹60.00'), findsOneWidget);

    await tester.tap(find.byKey(Key('payer-$riya')));
    await tester.pumpAndSettle();
    expect(find.text('You owe Riya ₹60.00'), findsOneWidget);

    await tester.tap(find.byKey(const Key('method-exact')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(Key('value-$riya')), '100');
    await tester.pumpAndSettle();
    expect(find.text('₹40.00 too much'), findsOneWidget);
    await tester.tap(find.byKey(const Key('method-equal')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('payer-me')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('split-done')));
    await tester.tap(find.byKey(const Key('split-done')));
    await tester.pumpAndSettle();
    expect(find.text('With Riya'), findsOneWidget);

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

  testWidgets('Statistics totals the period and switches range', (tester) async {
    final model = newModel();
    final food = model.store.categories().first.id;
    model.store.addSpend(title: 'Groceries', total: 32650, categoryId: food, day: model.today);
    model.store.addSpend(title: 'Lunch', total: 14000, categoryId: food, day: DateTime(2026, 11, 22));
    model.store.addSpend(title: 'Rent', total: 280000, categoryId: food, day: DateTime(2026, 10, 1));
    await start(tester, model);

    await tester.tap(find.byKey(const Key('nav-statistics')));
    await tester.pumpAndSettle();
    String total() => tester.widget<Text>(find.byKey(const Key('stats-total'))).data!;
    expect(total(), '₹467');
    expect(find.text('100% of spending'), findsOneWidget);

    await tester.tap(find.byKey(const Key('range-year')));
    await tester.pumpAndSettle();
    expect(total(), '₹3,267');

    await tester.tap(find.byKey(const Key('range-week')));
    await tester.pumpAndSettle();
    expect(total(), '₹467');
    expect(tester.widget<Text>(find.byKey(const Key('stats-period'))).data, 'Last 7 days · Today');
  });

  testWidgets('Stubs shows one receipt per week with its total', (tester) async {
    final model = newModel();
    final food = model.store.categories().first.id;
    model.store.addSpend(title: 'Groceries', total: 32650, categoryId: food, day: model.today);
    model.store.addSpend(title: 'Books', total: 82000, categoryId: food, day: DateTime(2026, 11, 9));
    await start(tester, model);

    await tester.tap(find.byKey(const Key('nav-stubs')));
    await tester.pumpAndSettle();
    expect(find.text('Week 4'), findsOneWidget);
    expect(find.text('Groceries'), findsOneWidget);
    expect(find.text('Books'), findsNothing);

    await tester.ensureVisible(find.byKey(const Key('week-2')));
    await tester.tap(find.byKey(const Key('week-2')));
    await tester.pumpAndSettle();
    expect(find.text('Books'), findsOneWidget);
    expect(find.text('₹820.00'), findsWidgets);
  });

  testWidgets('category is picked from a sheet and saved with the spend', (tester) async {
    final model = newModel();
    await start(tester, model);

    await tester.tap(find.byKey(const Key('fab-add')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('amount-field')), '640');
    await tester.tap(find.byKey(const Key('category-row')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('cat-Electricity')));
    await tester.pumpAndSettle();
    expect(find.text('Electricity'), findsOneWidget);

    await tester.tap(find.byKey(const Key('save-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    final entry = model.store.entriesForMonth(model.today).single;
    final names = {for (final c in model.store.categories()) c.id: c.name};
    expect(entry.title, 'Electricity');
    expect(names[entry.categoryId], 'Electricity');
  });
}
