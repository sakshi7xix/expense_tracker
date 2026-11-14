@Tags(['golden'])
library;

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:stub/core/theme.dart';
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
}
