@Tags(['golden'])
library;

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:stub/app.dart';
import 'package:stub/app_model.dart';
import 'package:stub/core/theme.dart';
import 'package:stub/data/db.dart';
import 'package:stub/data/store.dart';
import 'package:stub/ui/kit/curled_receipt.dart';
import 'package:stub/ui/kit/paper.dart';

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

  Future<AppModel> phone(WidgetTester tester) async {
    await _loadFont('Nunito', ['Nunito_600SemiBold.ttf', 'Nunito_700Bold.ttf', 'Nunito_800ExtraBold.ttf', 'Nunito_900Black.ttf']);
    await _loadFont('IBMPlexMono', ['IBMPlexMono_400Regular.ttf', 'IBMPlexMono_500Medium.ttf']);
    await _loadFont('MaterialIcons', []);
    debugDisableShadows = false;
    addTearDown(() => debugDisableShadows = true);
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final model = AppModel(StubStore(openMemoryDb()), clock: () => DateTime(2026, 11, 25, 10));
    final s = model.store;
    s.budget = 1500000;
    s.firstRunDone = true;
    final c = {for (final x in s.categories()) x.name: x.id};
    final riya = s.addFriend('Riya');
    s.addFriend('Aman');
    s.addFriend('Dev');
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

  testWidgets('weekly receipts preview', (tester) async {
    await phone(tester);
    await tester.tap(find.byKey(const Key('nav-receipts')));
    await tester.pumpAndSettle();
    await expectLater(find.byKey(const Key('screen')), matchesGoldenFile('receipts.png'));
    await tester.dragFrom(const Offset(195, 300), const Offset(95, 0));
    await tester.pump(const Duration(milliseconds: 16));
    await expectLater(find.byKey(const Key('screen')), matchesGoldenFile('receipts_turning.png'));
  });
}
