import 'package:flutter_test/flutter_test.dart';
import 'package:stub/app.dart';

void main() {
  testWidgets('app opens on the placeholder home', (tester) async {
    await tester.pumpWidget(const StubApp());
    expect(find.text('stub'), findsOneWidget);
    expect(find.text('₹3,830'), findsOneWidget);
  });
}
