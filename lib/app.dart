import 'package:material_ui/material_ui.dart';

import 'core/theme.dart';
import 'features/home/home_screen.dart';

class StubApp extends StatelessWidget {
  const StubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stub',
      debugShowCheckedModeBanner: false,
      theme: buildStubTheme(),
      home: const HomeScreen(),
    );
  }
}
