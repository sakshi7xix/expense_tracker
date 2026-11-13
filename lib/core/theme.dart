import 'package:flutter/material.dart';

import 'tokens.dart';

ThemeData buildStubTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: StubColors.pop,
    brightness: Brightness.light,
  ).copyWith(
    primary: StubColors.pop,
    onPrimary: Colors.white,
    surface: StubColors.page,
    onSurface: StubColors.ink,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: StubColors.page,
    textTheme: const TextTheme(
      displaySmall: TextStyle(
        fontSize: 36,
        fontWeight: FontWeight.w900,
        letterSpacing: -0.7,
        color: StubColors.ink,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: StubColors.ink,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: StubColors.muted,
      ),
    ),
  );
}
