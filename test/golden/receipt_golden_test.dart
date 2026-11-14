@Tags(['golden'])
library;

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:stub/app.dart';
import 'package:stub/app_model.dart';
import 'package:stub/core/theme.dart';
import 'package:stub/data/auth.dart';
import 'package:stub/data/db.dart';
import 'package:stub/data/store.dart';
import 'package:stub/ui/kit/curled_receipt.dart';
import 'package:stub/ui/kit/paper.dart';

import '../fake_auth.dart';

Future<void> _loadFont(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final f in files) {
    final bytes = File('assets/fonts/$f').readAsBytesSync();
    loader.addFont(Future.value(ByteData.view(bytes.buffer)));
  }
  await loader.load();
}

void main() {
  testWidgets('curled receipt renders', (tester) async {
    await _loadFont('Nunito', ['Nunito_700Bold.ttf', 'Nunito_800ExtraBold.ttf', 'Nunito_900Black.ttf']);
    await _loadFont('IBMPlexMono', ['IBMPlexMono_400Regular.ttf', 'IBMPlexMono_500Medium.ttf']);
    debugDisableShadows = false;
    addTearDown(() => debugDisableShadows = true);
    tester.view.physicalSize = const Size(390 * 3, 700 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildStubTheme(),
        home: Scaffold(
          body: Center(
            child: RepaintBoundary(
              key: const Key('shot'),
              child: Container(
                color: const Color(0xFFF3F2EF),
                padding: const EdgeInsets.all(30),
                child: const CurledReceipt(
                  subtitle: 'WED 25 NOV 2026 · FOOD',
                  lines: [
                    ReceiptLine.rule(),
                    ReceiptLine('Chai with Riya', '₹120.00'),
                    ReceiptLine('Riya owes you ₹60.00', ''),
                    ReceiptLine('Your share', '₹60.00'),
                    ReceiptLine.rule(),
                    ReceiptLine('Today so far', '₹386.50'),
                    ReceiptLine('LEFT', '₹3,769.50', bold: true),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await expectLater(find.byKey(const Key('shot')), matchesGoldenFile('receipt.png'));
  });

  Future<AppModel> phone(WidgetTester tester, {Auth? auth}) async {
    await _loadFont('Nunito', ['Nunito_600SemiBold.ttf', 'Nunito_700Bold.ttf', 'Nunito_800ExtraBold.ttf', 'Nunito_900Black.ttf']);
    await _loadFont('IBMPlexMono', ['IBMPlexMono_400Regular.ttf', 'IBMPlexMono_500Medium.ttf']);
    await _loadFont('MaterialIcons', []);
    debugDisableShadows = false;
    addTearDown(() => debugDisableShadows = true);
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final model = AppModel(StubStore(openMemoryDb()), clock: () => DateTime(2026, 11, 25, 10), auth: auth);
    final s = model.store;
    s.budget = 1500000;
    s.firstRunDone = true;
    final c = {for (final x in s.categories()) x.name: x.id};
    final riya = s.addFriend('Riya');
    final aman = s.addFriend('Aman');
    final dev = s.addFriend('Dev');
    final flat = s.addGroup('Flatmates', [riya, aman, dev]);
    s.addSpend(title: 'Groceries for the flat', total: 120000, categoryId: c['Groceries']!, day: DateTime(2026, 11, 24), friendShares: {riya: 30000, aman: 30000, dev: 30000}, groupId: flat);
    s.addSpend(title: 'Gas cylinder', total: 90000, categoryId: c['Water & gas']!, day: DateTime(2026, 11, 20), friendShares: {riya: 22500, aman: 22500, dev: 22500}, payerFriendId: aman, groupId: flat);
    s.addGroup('Goa trip', [riya, dev]);
    s.settle(dev, 10000, day: DateTime(2026, 11, 23));
    s.addSpend(title: 'Groceries', total: 32650, categoryId: c['Groceries']!, day: model.today);
    s.addSpend(title: 'Chai with Riya', total: 4000, categoryId: c['Food']!, day: model.today, friendShares: {riya: 2000});
    s.addSpend(title: 'Netflix', total: 19900, categoryId: c['Subscriptions']!, day: DateTime(2026, 11, 12));
    s.addSpend(title: 'Electricity', total: 64000, categoryId: c['Electricity']!, day: DateTime(2026, 11, 8));
    s.addSpend(title: 'Rent', total: 800000, categoryId: c['Rent']!, day: DateTime(2026, 11, 1));
    await tester.pumpWidget(RepaintBoundary(key: const Key('screen'), child: StubApp(model: model)));
    await tester.pumpAndSettle();
    return model;
  }

  testWidgets('home preview', (tester) async {
    await phone(tester);
    await expectLater(find.byKey(const Key('screen')), matchesGoldenFile('home.png'));
  });

  testWidgets('add spend preview', (tester) async {
    await phone(tester);
    await tester.tap(find.byKey(const Key('fab-add')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('amount-field')), '120');
    await tester.enterText(find.byKey(const Key('title-field')), 'Chai with Riya');
    await tester.pumpAndSettle();
    await expectLater(find.byKey(const Key('screen')), matchesGoldenFile('add.png'));
    await tester.tap(find.byKey(const Key('category-row')));
    await tester.pumpAndSettle();
    await expectLater(find.byKey(const Key('screen')), matchesGoldenFile('categories.png'));
  });

  testWidgets('pop-up previews', (tester) async {
    final model = await phone(tester);
    final riya = model.store.friends().first.id;
    await tester.tap(find.byKey(const Key('fab-add')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('amount-field')), '120');
    await tester.tap(find.byKey(const Key('split-row')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('friend-$riya')));
    await tester.pumpAndSettle();
    await expectLater(find.byKey(const Key('screen')), matchesGoldenFile('split.png'));
    await tester.tap(find.byKey(const Key('new-friend')));
    await tester.pumpAndSettle();
    await expectLater(find.byKey(const Key('screen')), matchesGoldenFile('add_friend.png'));
  });

  testWidgets('spend receipt preview', (tester) async {
    await phone(tester);
    await tester.tap(find.text('Chai with Riya'));
    await tester.pumpAndSettle();
    await expectLater(find.byKey(const Key('screen')), matchesGoldenFile('spend_receipt.png'));
  });

  testWidgets('statistics preview', (tester) async {
    await phone(tester);
    await tester.tap(find.byKey(const Key('nav-statistics')));
    await tester.pumpAndSettle();
    await expectLater(find.byKey(const Key('screen')), matchesGoldenFile('stats.png'));
  });

  testWidgets('friends previews', (tester) async {
    await phone(tester);
    await tester.tap(find.byKey(const Key('nav-friends')));
    await tester.pumpAndSettle();
    await expectLater(find.byKey(const Key('screen')), matchesGoldenFile('friends.png'));
    await tester.tap(find.byKey(const Key('seg-groups')));
    await tester.pumpAndSettle();
    await expectLater(find.byKey(const Key('screen')), matchesGoldenFile('groups.png'));
    await tester.tap(find.text('Flatmates'));
    await tester.pumpAndSettle();
    await expectLater(find.byKey(const Key('screen')), matchesGoldenFile('group_sheet.png'));
    await tester.tapAt(const Offset(195, 40));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('seg-activity')));
    await tester.pumpAndSettle();
    await expectLater(find.byKey(const Key('screen')), matchesGoldenFile('activity.png'));
    await tester.tap(find.byKey(const Key('nav-home')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('fab-add')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('amount-field')), '400');
    await tester.tap(find.byKey(const Key('split-row')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Goa trip'));
    await tester.pumpAndSettle();
    await expectLater(find.byKey(const Key('screen')), matchesGoldenFile('split_group.png'));
  });

  testWidgets('account previews', (tester) async {
    await phone(tester, auth: FakeAuth());
    await tester.tap(find.byKey(const Key('open-settings')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings-sign-in')));
    await tester.pumpAndSettle();
    await expectLater(find.byKey(const Key('screen')), matchesGoldenFile('signin_welcome.png'));
    await tester.tap(find.byKey(const Key('signin-start')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('signin-email')), 'you@example.com');
    await tester.pumpAndSettle();
    await expectLater(find.byKey(const Key('screen')), matchesGoldenFile('signin_email.png'));
    await tester.tap(find.byKey(const Key('signin-send')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('signin-code')), '1234');
    await tester.pumpAndSettle();
    await expectLater(find.byKey(const Key('screen')), matchesGoldenFile('signin_code.png'));
    await tester.enterText(find.byKey(const Key('signin-code')), '123456');
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('signin-name')), 'Sakshi');
    await tester.pumpAndSettle();
    await expectLater(find.byKey(const Key('screen')), matchesGoldenFile('signin_profile.png'));
    await tester.tap(find.byKey(const Key('signin-create')));
    await tester.pumpAndSettle();
    await expectLater(find.byKey(const Key('screen')), matchesGoldenFile('settings.png'));
  });
}
