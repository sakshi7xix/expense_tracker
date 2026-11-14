import 'package:material_ui/material_ui.dart';

/// Design tokens from the "Stub, quiet" prototype.
/// Neutral paper tones and ink black, an orange accent for actions, and a colour
/// per category and per friend (see categories.dart).
abstract final class StubColors {
  static const page = Color(0xFFF3F2EF);
  static const surface = Color(0xFFFFFFFF);
  static const soft = Color(0xFFEFEEEB);
  static const ink = Color(0xFF1F1F21);
  static const muted = Color(0xFF85848A);
  static const line = Color(0x0F000000);
  static const pop = Color(0xFFF26B2A);
  static const popDark = Color(0xFFD0531A);
  static const owed = Color(0xFF2E7352);
  static const owe = Color(0xFF9A4A3A);
  static const cardTop = Color(0xFF3C3C42);
  static const cardBottom = Color(0xFF19191C);
}

abstract final class StubRadius {
  static const control = 14.0;
  static const row = 18.0;
  static const card = 24.0;
  static const pill = 27.0;
}

abstract final class StubSpace {
  static const gutter = 16.0;
  static const gap = 8.0;
}
