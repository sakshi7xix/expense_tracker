import 'package:material_ui/material_ui.dart';

import '../../core/money.dart';

/// Placeholder Home for the setup phase. The real screen arrives in D5.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('stub', style: text.titleMedium),
            const SizedBox(height: 8),
            Text(formatInr(383000), style: text.displaySmall),
            Text('left this month', style: text.bodyMedium),
          ],
        ),
      ),
    );
  }
}
