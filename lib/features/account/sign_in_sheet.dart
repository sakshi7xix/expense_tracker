import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../app_model.dart';
import '../../core/tokens.dart';
import '../../data/auth.dart';
import '../../ui/kit/glass.dart';
import '../../ui/kit/kit.dart';
import '../../ui/kit/motion.dart';

/// Email, then the emailed code, then (first time only) name and 18+.
/// Returns true when the person ends up signed in with a profile.
Future<bool?> showSignIn(BuildContext context) {
  return showGlassSheet<bool>(context, (_) => SignInSheet());
}

enum _Step { email, code, profile }

class SignInSheet extends StatefulWidget {
  const SignInSheet({super.key});

  @override
  State<SignInSheet> createState() => _SignInSheetState();
}

class _SignInSheetState extends State<SignInSheet> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _name = TextEditingController();
  _Step _step = _Step.email;
  bool _busy = false;
  bool _adult = false;
  String? _error;
  int _wait = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _email.dispose();
    _code.dispose();
    _name.dispose();
    super.dispose();
  }

  Auth get _auth => StubScope.of(context).auth;

  /// Runs an online call with a spinner, showing any failure under the field.
  Future<bool> _run(Future<void> Function() call) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await call();
      return true;
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _startWait() {
    _timer?.cancel();
    setState(() => _wait = 60);
    _timer = Timer.periodic(Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _wait--);
      if (_wait <= 0) t.cancel();
    });
  }

  Future<void> _send() async {
    if (!looksLikeEmail(_email.text)) {
      setState(() => _error = 'That email doesn’t look right');
      return;
    }
    if (await _run(() => _auth.sendCode(_email.text))) {
      _code.clear();
      setState(() => _step = _Step.code);
      _startWait();
    }
  }

  Future<void> _verify() async {
    if (_code.text.length != 6) return;
    if (!await _run(() => _auth.verifyCode(_email.text, _code.text))) return;
    _timer?.cancel();
    if (!mounted) return;
    if (_auth.account?.needsProfile ?? true) {
      HapticFeedback.lightImpact();
      setState(() => _step = _Step.profile);
    } else {
      _done();
    }
  }

  Future<void> _create() async {
    final name = cleanName(_name.text);
    if (name == null) return setState(() => _error = 'Add your name');
    if (!_adult) return setState(() => _error = 'You need to be 18 or older to use online splitting');
    if (await _run(() => _auth.saveProfile(name))) _done();
  }

  void _done() {
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(22, 10, 22, 16),
          child: AnimatedSize(
            duration: Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: Column(
              key: ValueKey(_step),
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(child: const SheetGrab()),
                ...switch (_step) {
                  _Step.email => _emailStep(),
                  _Step.code => _codeStep(),
                  _Step.profile => _profileStep(),
                },
                if (_error != null)
                  Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: Text(
                      _error!,
                      key: Key('signin-error'),
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: StubColors.owe),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _title(String title, String line) {
    return Column(
      children: [
        Text(title, textAlign: TextAlign.center, style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: StubColors.ink)),
        SizedBox(height: 6),
        Text(line, textAlign: TextAlign.center, style: TextStyle(fontSize: 13.5, height: 1.45, fontWeight: FontWeight.w700, color: StubColors.muted)),
        SizedBox(height: 18),
      ],
    );
  }

  Widget _button(String label, String key, VoidCallback onTap) {
    return Padding(
      padding: EdgeInsets.only(top: 16),
      child: _busy
          ? Center(child: SizedBox(height: 48, child: Center(child: CircularProgressIndicator(color: StubColors.pop))))
          : PillButton(key: Key(key), label: label, onPressed: onTap),
    );
  }

  static const _plain = InputDecoration(border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none);

  List<Widget> _emailStep() => [
        _title('Split with friends', 'Sign in so friends see the same splits on their phones. Your own spends stay on this phone.'),
        SoftCard(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: TextField(
            key: Key('signin-email'),
            controller: _email,
            autofocus: true,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _send(),
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: StubColors.ink),
            decoration: _plain.copyWith(hintText: 'Your email', icon: Icon(Icons.mail_outline_rounded, color: StubColors.muted)),
          ),
        ),
        _button('Send code', 'signin-send', _send),
        SizedBox(height: 12),
        Text(
          'By continuing you agree to the Terms of use and Privacy policy, in Settings.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: StubColors.muted),
        ),
      ];

  List<Widget> _codeStep() => [
        _title('Check your email', 'We sent a 6-digit code to ${_email.text.trim()}'),
        SoftCard(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          child: TextField(
            key: Key('signin-code'),
            controller: _code,
            autofocus: true,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            autofillHints: const [AutofillHints.oneTimeCode],
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
            onChanged: (v) {
              if (_error != null) setState(() => _error = null);
              if (v.length == 6) _verify();
            },
            style: TextStyle(fontFamily: 'IBMPlexMono', fontSize: 30, letterSpacing: 12, fontWeight: FontWeight.w500, color: StubColors.ink),
            decoration: _plain.copyWith(hintText: '••••••', counterText: ''),
          ),
        ),
        _button('Continue', 'signin-verify', _verify),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              key: Key('signin-resend'),
              onPressed: _wait > 0 || _busy ? null : _send,
              child: Text(_wait > 0 ? 'Send again in 0:${_wait.toString().padLeft(2, '0')}' : 'Send again'),
            ),
            TextButton(
              onPressed: () {
                _timer?.cancel();
                setState(() {
                  _step = _Step.email;
                  _error = null;
                });
              },
              child: Text('Change email'),
            ),
          ],
        ),
      ];

  List<Widget> _profileStep() => [
        _title('About you', 'Friends will see this name on shared expenses.'),
        SoftCard(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: TextField(
            key: Key('signin-name'),
            controller: _name,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            autofillHints: const [AutofillHints.name],
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: StubColors.ink),
            decoration: _plain.copyWith(hintText: 'Your name', icon: Icon(Icons.person_outline_rounded, color: StubColors.muted)),
          ),
        ),
        SizedBox(height: 12),
        SoftCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.shield_outlined, size: 18, color: StubColors.owed),
                  SizedBox(width: 8),
                  Text('What goes online', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: StubColors.ink)),
                ],
              ),
              SizedBox(height: 6),
              Text(
                'Your name, your email, and only the expenses you split, so friends can see them. '
                'Your budget, personal spends and statistics stay on this phone. '
                'You can delete your account any time in Settings.',
                style: TextStyle(fontSize: 12.5, height: 1.5, fontWeight: FontWeight.w700, color: StubColors.muted),
              ),
            ],
          ),
        ),
        SizedBox(height: 8),
        Pressable(
          key: Key('signin-adult'),
          scale: 0.97,
          label: 'I am 18 or older',
          onTap: () => setState(() {
            _adult = !_adult;
            _error = null;
          }),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 8, horizontal: 2),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: Duration(milliseconds: 200),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _adult ? StubColors.owed : Colors.transparent,
                    border: Border.all(color: _adult ? StubColors.owed : Color(0xFFC9C8CD), width: 1.8),
                  ),
                  child: Icon(Icons.check_rounded, size: 16, color: _adult ? Colors.white : Colors.transparent),
                ),
                SizedBox(width: 10),
                ExcludeSemantics(
                  child: Text('I’m 18 or older', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: StubColors.ink)),
                ),
              ],
            ),
          ),
        ),
        _button('Create account', 'signin-create', _create),
      ];
}
