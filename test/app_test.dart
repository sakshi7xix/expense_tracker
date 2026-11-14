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
    expect(find.text('Welcome to Bilby'), findsOneWidget);

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

  testWidgets('adding a spend prints a receipt and updates Home', (tester) async {
    final model = newModel();
    await start(tester, model);

    await tester.tap(find.byKey(const Key('fab-add')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('amount-field')), '120');
    await tester.enterText(find.byKey(const Key('title-field')), 'Chai with Riya');
    await tester.tap(find.byKey(const Key('save-button')));
    await tester.pumpAndSettle();
    expect(find.text('RECEIPT'), findsOneWidget);
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

  testWidgets('tapping a spend opens its receipt, which can delete it', (tester) async {
    final model = newModel();
    final riya = model.store.addFriend('Riya');
    final food = model.store.categories().first.id;
    model.store.addSpend(title: 'Chai with Riya', total: 4000, categoryId: food, day: model.today, friendShares: {riya: 2000});
    await start(tester, model);

    await tester.tap(find.text('Chai with Riya'));
    await tester.pumpAndSettle();
    expect(find.text('RECEIPT'), findsOneWidget);
    expect(find.text('Riya owes you'), findsOneWidget);
    expect(find.text('YOUR SHARE'), findsOneWidget);

    await tester.tap(find.byKey(const Key('receipt-delete')));
    await tester.pumpAndSettle();
    expect(model.store.spentInMonth(model.today), 0);
    expect(model.store.balanceOf(riya), 0);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(model.store.spentInMonth(model.today), 2000);
  });

  testWidgets('a spend can be renamed from its receipt', (tester) async {
    final model = newModel();
    final food = model.store.categories().first.id;
    model.store.addSpend(title: 'Chai', total: 2000, categoryId: food, day: model.today);
    await start(tester, model);

    await tester.tap(find.text('Chai'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('receipt-edit')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('edit-title')), 'Masala chai');
    await tester.tap(find.byKey(const Key('edit-save')));
    await tester.pumpAndSettle();
    expect(model.store.entriesForMonth(model.today).single.title, 'Masala chai');
    expect(find.text('Masala chai'), findsOneWidget);
  });

  testWidgets('a group is made, then a spend is split with everyone in it', (tester) async {
    final model = newModel();
    final riya = model.store.addFriend('Riya');
    final aman = model.store.addFriend('Aman');
    await start(tester, model);

    await tester.tap(find.byKey(const Key('nav-friends')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('seg-groups')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('new-group')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('group-save')));
    await tester.pump();
    expect(find.text('Give the group a name'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('group-name')), 'Flatmates');
    await tester.tap(find.byKey(Key('member-$riya')));
    await tester.tap(find.byKey(Key('member-$aman')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('group-save')));
    await tester.pumpAndSettle();
    final flat = model.store.groups().single;
    expect(flat.memberIds, [riya, aman]);

    await tester.tap(find.byKey(Key('group-row-${flat.id}')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('group-add-spend')));
    await tester.tap(find.byKey(const Key('group-add-spend')));
    await tester.pumpAndSettle();
    expect(find.text('With Flatmates'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('amount-field')), '900');
    await tester.enterText(find.byKey(const Key('title-field')), 'Groceries');
    await tester.tap(find.byKey(const Key('save-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    final summary = model.store.groupSummary(flat.id);
    expect(summary.spent, 90000);
    expect(summary.balances, {riya: 30000, aman: 30000});
    expect(model.store.spentInMonth(model.today), 30000);
    expect(find.text('you are owed ₹600'), findsOneWidget);

    await tester.tap(find.byKey(const Key('seg-activity')));
    await tester.pumpAndSettle();
    expect(find.text('Today'), findsOneWidget);
    expect(find.textContaining('Riya owes you ₹300'), findsOneWidget);
  });

  testWidgets('picking a group in the split sheet adds its members', (tester) async {
    final model = newModel();
    final riya = model.store.addFriend('Riya');
    final aman = model.store.addFriend('Aman');
    final dev = model.store.addFriend('Dev');
    final trip = model.store.addGroup('Goa trip', [riya, aman]);
    await start(tester, model);

    await tester.tap(find.byKey(const Key('fab-add')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('amount-field')), '300');
    await tester.tap(find.byKey(const Key('split-row')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('group-$trip')));
    await tester.pumpAndSettle();
    expect(find.text('Riya owes you ₹100.00'), findsOneWidget);
    await tester.tap(find.byKey(Key('friend-$dev')));
    await tester.pumpAndSettle();
    expect(find.text('Dev owes you ₹75.00'), findsOneWidget);
    await tester.tap(find.byKey(Key('friend-$dev')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('split-done')));
    await tester.tap(find.byKey(const Key('split-done')));
    await tester.pumpAndSettle();
    expect(find.text('With Riya, Aman'), findsOneWidget, reason: 'adding Dev turned it into a plain split');
  });

  testWidgets('a reminder is copied for a friend who owes you', (tester) async {
    final model = newModel();
    final riya = model.store.addFriend('Riya');
    final food = model.store.categories().first.id;
    model.store.addSpend(title: 'Dinner', total: 12000, categoryId: food, day: model.today, friendShares: {riya: 6000});
    await start(tester, model);
    await tester.tap(find.byKey(const Key('nav-friends')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('friend-row-$riya')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('remind-button')));
    await tester.tap(find.byKey(const Key('remind-button')));
    await tester.pumpAndSettle();
    expect(find.text('Reminder copied. Paste it in a chat with Riya.'), findsOneWidget);
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

  testWidgets('the + button only shows on Home', (tester) async {
    await start(tester, newModel());
    expect(find.byKey(const Key('fab-add')), findsOneWidget);
    await tester.tap(find.byKey(const Key('nav-friends')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('fab-add')), findsNothing);
    await tester.tap(find.byKey(const Key('nav-home')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('fab-add')), findsOneWidget);
  });
}
