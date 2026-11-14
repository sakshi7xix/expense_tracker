import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../app_model.dart';
import '../../core/config.dart';
import '../../core/money.dart';
import '../../core/tokens.dart';
import '../../data/auth.dart';
import '../../ui/kit/glass.dart';
import '../../ui/kit/kit.dart';
import '../../ui/kit/motion.dart';
import '../account/sign_in_page.dart';
import 'legal_page.dart';

/// Profile, budget, the legal pages and account controls.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final model = StubScope.of(context);
    final auth = model.auth;
    final account = auth.account;
    void open(Widget page) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

    return Scaffold(
      appBar: AppBar(title: Text('Settings'), backgroundColor: StubColors.page, surfaceTintColor: Colors.transparent),
      body: ListView(
        padding: EdgeInsets.fromLTRB(StubSpace.gutter, 4, StubSpace.gutter, 32),
        children: [
          _Profile(account: account, canSignIn: auth.available),
          _Label('Money'),
          _Row(
            key: Key('edit-budget'),
            icon: Icons.account_balance_wallet_outlined,
            title: 'Monthly budget',
            detail: formatInr(model.store.budget),
            onTap: () => showDialog<void>(context: context, barrierColor: glassBarrier, builder: (_) => _BudgetDialog()),
          ),
          _Label('About'),
          _Row(
            key: Key('open-privacy'),
            icon: Icons.shield_outlined,
            title: 'Privacy policy',
            onTap: () => open(LegalPage(title: 'Privacy policy', sections: privacySections)),
          ),
          _Row(
            icon: Icons.description_outlined,
            title: 'Terms of use',
            onTap: () => open(LegalPage(title: 'Terms of use', sections: termsSections)),
          ),
          _Row(
            key: Key('open-licences'),
            icon: Icons.copyright_outlined,
            title: 'Licences',
            onTap: () => showLicensePage(context: context, applicationName: 'Expenses'),
          ),
          _Row(
            key: Key('open-help'),
            icon: Icons.help_outline_rounded,
            title: 'Help and complaints',
            detail: supportEmail,
            onTap: () {
              Clipboard.setData(ClipboardData(text: supportEmail));
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(content: Text('Email address copied')));
            },
          ),
          if (account != null) ...[
            _Label('Account'),
            _Row(
              key: Key('sign-out'),
              icon: Icons.logout_rounded,
              title: 'Sign out',
              detail: 'This phone keeps its data',
              onTap: () => auth.signOut(),
            ),
            _Row(
              key: Key('delete-account'),
              icon: Icons.delete_outline_rounded,
              title: 'Delete account',
              danger: true,
              onTap: () => showGlassSheet<void>(context, (_) => _DeleteSheet()),
            ),
          ],
        ],
      ),
    );
  }
}

class _Profile extends StatelessWidget {
  const _Profile({required this.account, required this.canSignIn});

  final Account? account;
  final bool canSignIn;

  @override
  Widget build(BuildContext context) {
    final a = account;
    return SoftCard(
      padding: EdgeInsets.all(14),
      child: Row(
        children: [
          a == null
              ? CircleAvatar(radius: 22, backgroundColor: StubColors.soft, child: Icon(Icons.person_rounded, color: StubColors.muted))
              : Avatar(name: a.name ?? a.email, radius: 22),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  a == null ? 'Not signed in' : a.name ?? 'Finish signing in',
                  key: Key('profile-name'),
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: StubColors.ink),
                ),
                Text(
                  a == null ? 'Everything stays on this phone' : a.email,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: StubColors.muted),
                ),
              ],
            ),
          ),
          if (canSignIn && (a == null || a.needsProfile))
            TextButton(
              key: Key('settings-sign-in'),
              onPressed: () => showSignIn(context),
              child: Text(a == null ? 'Sign in' : 'Finish', style: TextStyle(fontWeight: FontWeight.w900, color: StubColors.pop)),
            ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(4, 20, 4, 8),
      child: Text(text, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: StubColors.muted)),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({super.key, required this.icon, required this.title, this.detail, this.danger = false, required this.onTap});

  final IconData icon;
  final String title;
  final String? detail;
  final bool danger;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colour = danger ? StubColors.owe : StubColors.ink;
    return Padding(
      padding: EdgeInsets.only(bottom: 6),
      child: Pressable(
        scale: 0.98,
        label: title,
        onTap: onTap,
        child: SoftCard(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: ExcludeSemantics(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: danger ? Color(0xFFFCE6DC) : StubColors.soft,
                  child: Icon(icon, size: 17, color: danger ? StubColors.owe : StubColors.muted),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: colour)),
                      if (detail != null)
                        Text(detail!, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: StubColors.muted)),
                    ],
                  ),
                ),
                if (!danger) Icon(Icons.chevron_right_rounded, color: Color(0xFFB4B3B8)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BudgetDialog extends StatefulWidget {
  @override
  State<_BudgetDialog> createState() => _BudgetDialogState();
}

class _BudgetDialogState extends State<_BudgetDialog> {
  late final _field = TextEditingController(text: '${StubScope.of(context).store.budget ~/ 100}');
  String? _error;

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  void _save() {
    final paise = parseAmount(_field.text);
    if (paise == null) return setState(() => _error = 'Type an amount, like 15000');
    StubScope.of(context).write((s) => s.budget = paise);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return GlassDialog(
      title: 'Monthly budget',
      content: TextField(
        key: Key('budget-input'),
        controller: _field,
        autofocus: true,
        keyboardType: TextInputType.numberWithOptions(decimal: true),
        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: StubColors.ink),
        decoration: InputDecoration(prefixText: '₹ ', errorText: _error),
        onSubmitted: (_) => _save(),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text('Cancel')),
        SizedBox(width: 6),
        PillButton(key: Key('budget-save'), label: 'Save', onPressed: _save),
      ],
    );
  }
}

class _DeleteSheet extends StatefulWidget {
  @override
  State<_DeleteSheet> createState() => _DeleteSheetState();
}

class _DeleteSheetState extends State<_DeleteSheet> {
  bool _busy = false;
  String? _error;

  Future<void> _delete() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await StubScope.of(context).auth.deleteAccount();
      if (!mounted) return;
      Navigator.of(context).pop();
      messenger.showSnackBar(SnackBar(content: Text('Your account was deleted')));
    } on AuthFailure catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(22, 10, 22, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: const SheetGrab()),
            Text('Delete your account?', textAlign: TextAlign.center, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: StubColors.ink)),
            SizedBox(height: 10),
            Text(
              'This removes your name, email and sign-in from our server, for good. Friends keep the expenses '
              'you shared with them, shown as "Deleted user". What is on this phone stays.',
              style: TextStyle(fontSize: 13.5, height: 1.5, fontWeight: FontWeight.w700, color: StubColors.muted),
            ),
            if (_error != null)
              Padding(
                padding: EdgeInsets.only(top: 10),
                child: Text(_error!, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700, color: StubColors.owe)),
              ),
            SizedBox(height: 18),
            _busy
                ? Center(child: CircularProgressIndicator(color: StubColors.owe))
                : FilledButton(
                    key: Key('confirm-delete'),
                    style: FilledButton.styleFrom(backgroundColor: StubColors.owe, minimumSize: Size.fromHeight(50)),
                    onPressed: _delete,
                    child: Text('Delete account', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  ),
            TextButton(onPressed: () => Navigator.of(context).pop(), child: Text('Cancel')),
          ],
        ),
      ),
    );
  }
}
