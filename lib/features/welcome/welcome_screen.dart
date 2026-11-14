import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../app_model.dart';
import '../../core/money.dart';
import '../../core/tokens.dart';
import '../../ui/kit/bilby_mark.dart';
import '../../ui/kit/kit.dart';
import '../account/sign_in_art.dart';

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
              LoopBuilder(
                period: Duration(milliseconds: 3200),
                builder: (context, t) {
                  // The ears give a little wiggle once every few seconds.
                  final k = t < 0.7 ? 0.0 : (t - 0.7) / 0.3;
                  return BilbyMark(size: 72, ears: 0.22 * math.sin(k * math.pi * 4) * (1 - k));
                },
              ),
              SizedBox(height: 18),
              Text('Welcome to Bilby', style: text.titleMedium),
              SizedBox(height: 12),
              Text('How much do you earn in a month?', style: text.displaySmall),
              SizedBox(height: 8),
              Text('Salary, pocket money or allowance. Bilby shows how much of it is left.', style: text.bodyMedium),
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
                  border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none,
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
