import 'package:material_ui/material_ui.dart';

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
    onSurfaceVariant: StubColors.muted,
    surfaceTint: Colors.transparent,
    surfaceContainerLowest: Colors.white,
    surfaceContainerLow: Color(0xFFF7F7F5),
    surfaceContainer: Color(0xFFF3F2EF),
    surfaceContainerHigh: Color(0xFFEFEEEB),
    surfaceContainerHighest: Color(0xFFE9E8E5),
    outline: Color(0xFFCFCED3),
    outlineVariant: Color(0xFFE4E3E0),
  );
  return ThemeData(
    useMaterial3: true,
    fontFamily: 'Nunito',
    colorScheme: scheme,
    scaffoldBackgroundColor: StubColors.page,
    dialogTheme: DialogThemeData(backgroundColor: Colors.white, surfaceTintColor: Colors.transparent),
    bottomSheetTheme: BottomSheetThemeData(backgroundColor: Colors.white, surfaceTintColor: Colors.transparent),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: StubColors.ink,
      behavior: SnackBarBehavior.floating,
      shape: StadiumBorder(),
    ),
    inputDecorationTheme: InputDecorationTheme(
      labelStyle: TextStyle(color: StubColors.muted, fontWeight: FontWeight.w700),
      floatingLabelStyle: TextStyle(color: StubColors.ink, fontWeight: FontWeight.w800),
      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFD5D4D9))),
      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: StubColors.ink, width: 1.6)),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: StubColors.pop,
      selectionColor: Color(0x40F26B2A),
      selectionHandleColor: StubColors.pop,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: StubColors.page,
      surfaceTintColor: StubColors.page,
      titleTextStyle: TextStyle(fontFamily: 'Nunito', fontSize: 17, fontWeight: FontWeight.w800, color: StubColors.ink),
    ),
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
