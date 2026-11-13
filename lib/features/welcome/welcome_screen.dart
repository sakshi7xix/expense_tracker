import 'package:material_ui/material_ui.dart';

import '../../app_model.dart';
import '../../core/money.dart';
import '../../core/tokens.dart';
import '../../ui/kit/kit.dart';

/// First run: ask what comes in each month, then open the app.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final _budget = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _budget.dispose();
    super.dispose();
  }

  void _start() {
    final paise = parseAmount(_budget.text);
    if (paise == null) {
      setState(() => _error = 'Type an amount, like 15000');
      return;
    }
    StubScope.of(context).write((store) {
      store.budget = paise;
      store.firstRunDone = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Spacer(),
              Text('stub', style: text.titleMedium),
              SizedBox(height: 12),
              Text('How much do you earn in a month?', style: text.displaySmall),
              SizedBox(height: 8),
              Text('Salary, pocket money or allowance. Stub shows how much of it is left.', style: text.bodyMedium),
              SizedBox(height: 28),
              TextField(
                key: Key('budget-field'),
                controller: _budget,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: StubColors.ink),
                decoration: InputDecoration(
                  prefixText: '₹ ',
                  hintText: '15000',
                  errorText: _error,
                  border: InputBorder.none,
                ),
                onSubmitted: (_) => _start(),
              ),
              Spacer(flex: 2),
              PillButton(label: 'Start', onPressed: _start),
            ],
          ),
        ),
      ),
    );
  }
}
