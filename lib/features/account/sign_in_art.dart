import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../core/tokens.dart';
import '../../ui/kit/curled_receipt.dart';
import '../../ui/kit/kit.dart';
import '../../ui/kit/motion.dart';
import '../../ui/kit/paper.dart';

/// Gives [builder] a value going 0 → 1 over and over while looping motion is
/// allowed, or a fixed 0.25 when it isn't (tests, reduce motion).
class LoopBuilder extends StatefulWidget {
  const LoopBuilder({super.key, required this.period, required this.builder});

  final Duration period;
  final Widget Function(BuildContext context, double t) builder;

  @override
  State<LoopBuilder> createState() => _LoopBuilderState();
}

class _LoopBuilderState extends State<LoopBuilder> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.period, value: 0.25);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (StubMotion.loops(context)) {
      if (!_c.isAnimating) _c.repeat();
    } else {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(animation: _c, builder: (context, _) => widget.builder(context, _c.value));
  }
}

double _wave(double t, [double phase = 0]) => math.sin((t + phase) * 2 * math.pi);

/// Welcome: a 3D receipt floating and swaying while friends circle it and
/// two coins bob.
class ReceiptOrbitArt extends StatelessWidget {
  const ReceiptOrbitArt({super.key});

  static const _friends = ['Riya', 'Aman', 'Dev'];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 250,
      height: 230,
      child: LoopBuilder(
        period: Duration(seconds: 14),
        builder: (context, t) {
          final sway = _wave(t * 3.5);
          return Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              for (final (i, name) in _friends.indexed)
                Transform.translate(
                  offset: Offset.fromDirection((t + i / 3) * 2 * math.pi, 108) + Offset(0, 4),
                  child: Container(
                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Color(0xFF2A2A2F), width: 3)),
                    child: Avatar(name: name, radius: 17),
                  ),
                ),
              Transform.translate(
                offset: Offset(0, -6 + 6 * sway),
                child: CurledReceipt(
                  width: 148,
                  tiltX: 0.28 + 0.05 * sway,
                  tiltY: -0.32 + 0.12 * sway,
                  tiltZ: 0.05 * sway,
                  curlTop: 6,
                  curlBottom: -9,
                  lines: [
                    ReceiptLine.rule(),
                    ReceiptLine('Dinner', '1,200'),
                    ReceiptLine('Riya', '300'),
                    ReceiptLine('Aman', '300'),
                    ReceiptLine.rule(),
                    ReceiptLine('YOU', '300', bold: true),
                  ],
                ),
              ),
              _coin(Offset(-110, -20 + 8 * _wave(t * 4.7)), 0.25 * _wave(t * 4.7)),
              _coin(Offset(104, 58 + 8 * _wave(t * 4.7, 0.5)), 0.25 * _wave(t * 4.7, 0.5)),
            ],
          );
        },
      ),
    );
  }

  Widget _coin(Offset at, double turn) {
    return Transform.translate(
      offset: at,
      child: Transform.rotate(
        angle: turn,
        child: Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(center: Alignment(-0.3, -0.4), colors: [Color(0xFFFFE08A), Color(0xFFF5B92E), Color(0xFFD99412)]),
            boxShadow: [BoxShadow(color: Color(0x40A0640A), blurRadius: 8, offset: Offset(0, 4))],
          ),
          child: Text('₹', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF9A6608))),
        ),
      ),
    );
  }
}

/// Email and code steps: an envelope rocking in a soft circle, with a paper
/// plane flying past when [plane] is on.
class EnvelopeArt extends StatelessWidget {
  const EnvelopeArt({super.key, this.plane = true, this.size = 118});

  final bool plane;
  final double size;

  @override
  Widget build(BuildContext context) {
    return LoopBuilder(
      period: Duration(milliseconds: 2600),
      builder: (context, t) => SizedBox(
        width: size + 40,
        height: size,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.08)),
            ),
            Transform.translate(
              offset: Offset(0, -3 * (1 + _wave(t, 0.25)) / 2),
              child: Transform.rotate(
                angle: 0.1 * _wave(t),
                child: Icon(Icons.mail_outline_rounded, size: size * 0.46, color: Color(0xFFFF9A5C)),
              ),
            ),
            if (plane)
              Positioned(
                right: 0,
                top: 0,
                child: Opacity(
                  opacity: (math.sin(t * math.pi)).clamp(0.0, 1.0),
                  child: Transform.translate(
                    offset: Offset(-30 + 50 * t, 20 - 40 * t),
                    child: Transform.rotate(
                      angle: -0.5,
                      child: Icon(Icons.send_rounded, size: 22, color: Colors.white.withValues(alpha: 0.7)),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// About you: the person's initial as a big avatar, gently breathing.
class InitialArt extends StatelessWidget {
  const InitialArt({super.key, required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final letter = name.trim().isEmpty ? '' : name.trim()[0].toUpperCase();
    return LoopBuilder(
      period: Duration(seconds: 3),
      builder: (context, t) => Transform.scale(
        scale: 1 + 0.04 * (1 + _wave(t)) / 2,
        child: Container(
          width: 100,
          height: 100,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            boxShadow: [BoxShadow(color: Color(0x33000000), blurRadius: 24, offset: Offset(0, 10))],
          ),
          child: AnimatedSwitcher(
            duration: Duration(milliseconds: 260),
            transitionBuilder: (child, a) => ScaleTransition(scale: a, child: child),
            child: letter.isEmpty
                ? Icon(Icons.person_rounded, key: ValueKey(''), size: 44, color: StubColors.muted)
                : Text(letter, key: ValueKey(letter), style: TextStyle(fontSize: 42, fontWeight: FontWeight.w900, color: StubColors.ink)),
          ),
        ),
      ),
    );
  }
}
