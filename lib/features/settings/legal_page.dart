import 'package:material_ui/material_ui.dart';

import '../../core/config.dart';
import '../../core/tokens.dart';

/// A plain-language page of short sections.
class LegalPage extends StatelessWidget {
  const LegalPage({super.key, required this.title, required this.sections});

  final String title;
  final List<(String, String)> sections;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title), backgroundColor: StubColors.page, surfaceTintColor: Colors.transparent),
      body: ListView(
        padding: EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          for (final (heading, body) in sections) ...[
            SizedBox(height: 16),
            Text(heading, style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w900, color: StubColors.ink)),
            SizedBox(height: 6),
            Text(body, style: TextStyle(fontSize: 14, height: 1.55, fontWeight: FontWeight.w600, color: Color(0xFF45444A))),
          ],
        ],
      ),
    );
  }
}

/// What the app keeps, where, and why. Have this reviewed by a lawyer before
/// publishing; it must stay true to what the code does.
const privacySections = [
  (
    'In short',
    'Your budget, your own spends and your statistics stay on your phone. If you sign in to split with '
        'friends, we keep your name, your email and the expenses you split, so the people in them can see them.'
  ),
  (
    'What we keep online',
    'Your name and email address, when you confirmed you are 18 or older, and (once splitting with friends '
        'online is turned on) the expenses you split: title, amounts, date, who paid and each person\'s share.'
  ),
  (
    'What we never collect',
    'Your address book. When you add a friend you pick one contact, and only what you pick is used. '
        'We don\'t sell data, show ads or use trackers.'
  ),
  (
    'Where it is kept',
    'On our database provider\'s servers in Mumbai, India, sent over encrypted connections. Your sign-in '
        'is stored in your phone\'s secure storage.'
  ),
  (
    'Deleting your account',
    'Settings → Delete account removes your name, email and sign-in. Friends keep expenses you shared with '
        'them, with your name shown as "Deleted user". What is on your phone stays until you delete the app.'
  ),
  ('Age', 'Online splitting is for people aged 18 or older.'),
  ('Questions and complaints', 'Write to $supportEmail. We reply as soon as we can, and within 30 days.'),
];

const termsSections = [
  (
    'What this app is',
    'Bilby is a way to keep track of your spending and of what friends owe each other. It is a record, not a bank '
        'or a payments service: it never holds or moves money.'
  ),
  (
    'Your records',
    'Balances are worked out from what you and your friends enter. Check them before you pay anyone. We are '
        'not responsible for disagreements between friends or for mistakes in what was entered.'
  ),
  ('Who can use it', 'You must be 18 or older to sign in and split with friends online.'),
  (
    'Fair use',
    'Don\'t use the app to send spam, harass anyone, or enter other people\'s details without a good reason.'
  ),
  (
    'No warranty',
    'The app is provided as it is. We work to keep it running and your data safe, but can\'t promise it will '
        'always be available or free of errors.'
  ),
  ('Contact', 'Questions about these terms: $supportEmail.'),
];
