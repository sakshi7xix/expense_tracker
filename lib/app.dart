import 'package:material_ui/material_ui.dart';

import 'app_model.dart';
import 'core/theme.dart';
import 'features/shell/shell.dart';
import 'features/welcome/welcome_screen.dart';

class StubApp extends StatelessWidget {
  const StubApp({super.key, required this.model});

  final AppModel model;

  @override
  Widget build(BuildContext context) {
    return StubScope(
      model: model,
      child: MaterialApp(
        title: 'Stub',
        debugShowCheckedModeBanner: false,
        theme: buildStubTheme(),
        home: _Root(),
      ),
    );
  }
}

class _Root extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final store = StubScope.of(context).store;
    return store.firstRunDone ? Shell() : WelcomeScreen();
  }
}
