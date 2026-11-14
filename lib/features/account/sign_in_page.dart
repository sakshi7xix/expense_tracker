import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../app_model.dart';
import '../../core/tokens.dart';
import '../../data/auth.dart';
import '../../ui/kit/kit.dart';
import 'sign_in_art.dart';

/// Opens sign-in as a full page. Returns true when the person ends up signed
/// in with a profile.
Future<bool?> showSignIn(BuildContext context) {
  return Navigator.of(context).push<bool>(
    PageRouteBuilder<bool>(
      transitionDuration: Duration(milliseconds: 420),
      reverseTransitionDuration: Duration(milliseconds: 260),
      pageBuilder: (context, animation, secondary) => SignInPage(),
      transitionsBuilder: (context, animation, secondary, child) {
        final a = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: a,
          child: ScaleTransition(scale: Tween(begin: 1.04, end: 1.0).animate(a), child: child),
        );
      },
    ),
  );
}

enum _Step { welcome, email, code, profile }

/// Charcoal dome with an animated picture on top, a white panel below that
/// slides up with each step's form.
class SignInPage extends StatefulWidget {
  const SignInPage({super.key});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> with SingleTickerProviderStateMixin {
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _name = TextEditingController();
  late final AnimationController _success = AnimationController(vsync: this, duration: Duration(milliseconds: 1100))
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) Navigator.of(context).pop(true);
    });
  _Step _step = _Step.welcome;
  bool _busy = false;
  String? _error;
  int _wait = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _success.dispose();
    _email.dispose();
    _code.dispose();
    _name.dispose();
    super.dispose();
  }

  Auth get _auth => StubScope.of(context).auth;

  void _go(_Step step) {
    _timer?.cancel();
    setState(() {
      _step = step;
      _error = null;
    });
  }

  Future<bool> _run(Future<void> Function() call) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await call();
      return true;
    } on AuthFailure catch (e) {
      HapticFeedback.heavyImpact();
      if (mounted) setState(() => _error = e.message);
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _send() async {
    if (!looksLikeEmail(_email.text)) {
      setState(() => _error = 'That email doesn’t look right');
      return;
    }
    if (!await _run(() => _auth.sendCode(_email.text)) || !mounted) return;
    _code.clear();
    _go(_Step.code);
    setState(() => _wait = 60);
    _timer = Timer.periodic(Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _wait--);
      if (_wait <= 0) t.cancel();
    });
  }

  Future<void> _verify() async {
    if (_code.text.length != 6 || _busy) return;
    if (!await _run(() => _auth.verifyCode(_email.text, _code.text)) || !mounted) {
      _code.clear();
      return;
    }
    if (_auth.account?.needsProfile ?? true) {
      HapticFeedback.lightImpact();
      _go(_Step.profile);
    } else {
      _finish();
    }
  }

  Future<void> _create() async {
    final name = cleanName(_name.text);
    if (name == null) return setState(() => _error = 'Add your name');
    if (await _run(() => _auth.saveProfile(name))) _finish();
  }

  void _finish() {
    _timer?.cancel();
    FocusScope.of(context).unfocus();
    HapticFeedback.mediumImpact();
    setState(() {});
    _success.forward();
  }

  void _back() {
    switch (_step) {
      case _Step.welcome:
        Navigator.of(context).pop(false);
      case _Step.email:
        _go(_Step.welcome);
      case _Step.code:
        _go(_Step.email);
      case _Step.profile:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final (title, line) = switch (_step) {
      _Step.welcome => ('Welcome', 'Your spends, and splits with friends'),
      _Step.email => ('Welcome', 'Sign in or create an account'),
      _Step.code => ('Check your email', 'Code sent to ${_email.text.trim()}'),
      _Step.profile => ('Nice to meet you', 'Friends will see this name'),
    };
    final art = switch (_step) {
      _Step.welcome => ReceiptOrbitArt(),
      _Step.email => EnvelopeArt(),
      _Step.code => EnvelopeArt(plane: false, size: 96),
      _Step.profile => ValueListenableBuilder(valueListenable: _name, builder: (context, v, _) => InitialArt(name: v.text)),
    };

    return PopScope(
      canPop: _step == _Step.welcome,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        backgroundColor: StubColors.page,
        body: LayoutBuilder(
          builder: (context, box) {
            final w = box.maxWidth;
            final domeHeight = box.maxHeight * (_step == _Step.welcome ? 0.98 : 0.9);
            return Stack(
              children: [
                AnimatedPositioned(
                  duration: Duration(milliseconds: 600),
                  curve: Curves.easeInOutCubic,
                  left: -w * 0.3,
                  right: -w * 0.3,
                  top: -box.maxHeight * 0.2,
                  height: domeHeight,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [StubColors.cardTop, Color(0xFF27272B), StubColors.cardBottom],
                      ),
                      borderRadius: BorderRadius.vertical(bottom: Radius.elliptical(w * 0.8, domeHeight * 0.5)),
                    ),
                  ),
                ),
                SafeArea(
                  bottom: false,
                  child: Column(
                    children: [
                      SizedBox(
                        height: 48,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: _step == _Step.profile
                              ? null
                              : Padding(
                                  padding: EdgeInsets.only(left: 12),
                                  child: IconButton(
                                    key: Key('signin-back'),
                                    tooltip: _step == _Step.welcome ? 'Close' : 'Back',
                                    style: IconButton.styleFrom(backgroundColor: Colors.white.withValues(alpha: 0.12)),
                                    icon: Icon(
                                      _step == _Step.welcome ? Icons.close_rounded : Icons.arrow_back_rounded,
                                      color: Colors.white,
                                    ),
                                    onPressed: _back,
                                  ),
                                ),
                        ),
                      ),
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: Duration(milliseconds: 450),
                          switchInCurve: Curves.easeOutCubic,
                          transitionBuilder: (child, a) => FadeTransition(
                            opacity: a,
                            child: SlideTransition(position: Tween(begin: Offset(0, 0.06), end: Offset.zero).animate(a), child: child),
                          ),
                          child: FittedBox(
                            key: ValueKey(_step),
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.topCenter,
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 24),
                              child: Column(
                                children: [
                                  Text(title, style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5)),
                                  SizedBox(height: 6),
                                  Text(line, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.6))),
                                  SizedBox(height: 22),
                                  art,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      AnimatedSwitcher(
                        duration: Duration(milliseconds: 520),
                        switchInCurve: Curves.easeOutBack,
                        switchOutCurve: Curves.easeIn,
                        transitionBuilder: (child, a) => SlideTransition(
                          position: Tween(begin: Offset(0, 1), end: Offset.zero).animate(a),
                          child: child,
                        ),
                        layoutBuilder: (current, previous) => Stack(
                          alignment: Alignment.bottomCenter,
                          children: [...previous, if (current != null) current],
                        ),
                        child: _Panel(key: ValueKey(_step), child: _form()),
                      ),
                    ],
                  ),
                ),
                if (_success.isAnimating || _success.isCompleted) _SuccessOverlay(progress: _success),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _form() {
    final error = _error == null
        ? SizedBox.shrink()
        : Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              _error!,
              key: Key('signin-error'),
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: StubColors.owe),
            ),
          );
    switch (_step) {
      case _Step.welcome:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Split with friends', style: _heading),
            SizedBox(height: 4),
            Text('They see the same splits on their phones. Your own spends stay on yours.', style: _muted),
            SizedBox(height: 18),
            PillButton(key: Key('signin-start'), label: 'Continue with email', onPressed: () => _go(_Step.email)),
            SizedBox(height: 10),
            FrostButton(key: Key('signin-later'), label: 'Not now', onPressed: () => Navigator.of(context).pop(false)),
          ],
        );
      case _Step.email:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Email address', style: _label),
            SizedBox(height: 6),
            _Field(
              child: TextField(
                key: Key('signin-email'),
                controller: _email,
                autofocus: true,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                style: _input,
                decoration: _plain.copyWith(hintText: 'you@example.com', icon: Icon(Icons.mail_outline_rounded, color: StubColors.muted)),
              ),
            ),
            error,
            SizedBox(height: 14),
            PillButton(key: Key('signin-send'), label: 'Send code', busy: _busy, onPressed: _send),
            SizedBox(height: 10),
            Text(
              'We’ll email you a 6-digit code, no password needed. By continuing you agree to the Terms of use and '
              'Privacy policy and confirm you’re 18 or older.',
              textAlign: TextAlign.center,
              style: _fine,
            ),
          ],
        );
      case _Step.code:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _CodeBoxes(controller: _code, onChanged: (v) {
              if (_error != null) setState(() => _error = null);
              setState(() {});
              if (v.length == 6) _verify();
            }),
            Center(child: error),
            SizedBox(height: 4),
            if (_busy) Padding(padding: EdgeInsets.all(8), child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: StubColors.pop)))),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  key: Key('signin-resend'),
                  onPressed: _wait > 0 || _busy ? null : _send,
                  child: Text(_wait > 0 ? 'Send again in 0:${_wait.toString().padLeft(2, '0')}' : 'Send again'),
                ),
                TextButton(onPressed: () => _go(_Step.email), child: Text('Change email')),
              ],
            ),
          ],
        );
      case _Step.profile:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Your name', style: _label),
            SizedBox(height: 6),
            _Field(
              child: TextField(
                key: Key('signin-name'),
                controller: _name,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                autofillHints: const [AutofillHints.name],
                onSubmitted: (_) => _create(),
                style: _input,
                decoration: _plain.copyWith(hintText: 'Your name'),
              ),
            ),
            error,
            SizedBox(height: 14),
            PillButton(key: Key('signin-create'), label: 'Create account', busy: _busy, onPressed: _create),
            SizedBox(height: 10),
            Text(
              'Only your name, email and the expenses you split go online. Your budget and own spends stay on this phone.',
              textAlign: TextAlign.center,
              style: _fine,
            ),
          ],
        );
    }
  }
}

const _plain = InputDecoration(border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none);
const _heading = TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: StubColors.ink, letterSpacing: -0.3);
const _muted = TextStyle(fontSize: 13.5, height: 1.45, fontWeight: FontWeight.w700, color: StubColors.muted);
const _label = TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: StubColors.muted);
const _input = TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: StubColors.ink);
const _fine = TextStyle(fontSize: 11.5, height: 1.5, fontWeight: FontWeight.w700, color: StubColors.muted);

/// The white panel at the bottom of the page.
class _Panel extends StatelessWidget {
  const _Panel({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(22, 24, 22, 16 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [BoxShadow(color: Color(0x101E1E28), blurRadius: 30, offset: Offset(0, -10))],
      ),
      child: child,
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      decoration: BoxDecoration(color: StubColors.page, borderRadius: BorderRadius.circular(16)),
      child: child,
    );
  }
}

/// Six boxes over one hidden field; each digit pops into its box.
class _CodeBoxes extends StatelessWidget {
  const _CodeBoxes({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final code = controller.text;
    return SizedBox(
      height: 56,
      child: Stack(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < 6; i++)
                Container(
                  width: 44,
                  height: 54,
                  margin: EdgeInsets.symmetric(horizontal: 3.5),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: StubColors.page,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: i == code.length ? StubColors.pop : Colors.transparent, width: 2),
                  ),
                  child: i < code.length
                      ? TweenAnimationBuilder<double>(
                          key: ValueKey('$i${code[i]}'),
                          tween: Tween(begin: 0.6, end: 1),
                          duration: Duration(milliseconds: 280),
                          curve: Curves.elasticOut,
                          builder: (context, s, child) => Transform.scale(scale: s, child: child),
                          child: Text(code[i], style: TextStyle(fontFamily: 'IBMPlexMono', fontSize: 22, fontWeight: FontWeight.w500, color: StubColors.ink)),
                        )
                      : null,
                ),
            ],
          ),
          Positioned.fill(
            child: TextField(
              key: Key('signin-code'),
              controller: controller,
              autofocus: true,
              showCursor: false,
              enableInteractiveSelection: false,
              keyboardType: TextInputType.number,
              autofillHints: const [AutofillHints.oneTimeCode],
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
              onChanged: onChanged,
              style: TextStyle(color: Colors.transparent),
              decoration: _plain.copyWith(counterText: ''),
            ),
          ),
        ],
      ),
    );
  }
}

/// "You're in": the page fades to the app's grey and a tick draws itself.
class _SuccessOverlay extends StatelessWidget {
  const _SuccessOverlay({required this.progress});

  final Animation<double> progress;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: progress,
      builder: (context, _) {
        final t = progress.value;
        final fade = Curves.easeOut.transform((t / 0.3).clamp(0.0, 1.0));
        final pop = Curves.elasticOut.transform(((t - 0.1) / 0.5).clamp(0.0, 1.0));
        final draw = Curves.easeOutCubic.transform(((t - 0.3) / 0.35).clamp(0.0, 1.0));
        return Positioned.fill(
          child: Opacity(
            opacity: fade,
            child: ColoredBox(
              color: StubColors.page,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Transform.scale(
                    scale: pop,
                    child: Container(
                      width: 92,
                      height: 92,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: StubColors.ink),
                      child: CustomPaint(painter: _TickPainter(draw)),
                    ),
                  ),
                  SizedBox(height: 18),
                  Opacity(opacity: draw, child: Text('You’re in', style: _heading)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TickPainter extends CustomPainter {
  _TickPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * 0.3, size.height * 0.52)
      ..lineTo(size.width * 0.45, size.height * 0.66)
      ..lineTo(size.width * 0.72, size.height * 0.36);
    final m = path.computeMetrics().first;
    canvas.drawPath(
      m.extractPath(0, m.length * progress),
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_TickPainter old) => old.progress != progress;
}
