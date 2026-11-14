import 'dart:async';

import 'package:stub/ui/kit/motion.dart';

/// Runs before every test file: looping animations would stop
/// `pumpAndSettle` from ever settling.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  StubMotion.ambient = false;
  await testMain();
}
