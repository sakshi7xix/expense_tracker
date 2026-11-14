import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/tokens.dart';
import 'motion.dart';

/// The one main action on a screen: orange, with a light that sweeps across
/// every few seconds and a soft glow that breathes behind it. Pressing sinks
/// it and sends a ripple out from the finger. With [busy] the sheen speeds up
/// and three dots bounce; with [done] it shrinks to a green circle with a tick.
class PillButton extends StatefulWidget {
  const PillButton({super.key, required this.label, required this.onPressed, this.busy = false, this.done = false});

  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final bool done;

  @override
  State<PillButton> createState() => _PillButtonState();
}

class _PillButtonState extends State<PillButton> with SingleTickerProviderStateMixin {
  late final AnimationController _loop = AnimationController(vsync: this, duration: Duration(milliseconds: 3200));
  bool _down = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncLoop();
  }

  @override
  void didUpdateWidget(PillButton old) {
    super.didUpdateWidget(old);
    _loop.duration = Duration(milliseconds: widget.busy ? 900 : 3200);
    _syncLoop();
  }

  void _syncLoop() {
    final run = StubMotion.loops(context) && !widget.done && widget.onPressed != null;
    if (run && !_loop.isAnimating) {
      _loop.repeat();
    } else if (!run && _loop.isAnimating) {
      _loop.stop();
    }
  }

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  void _tap() {
    if (widget.busy || widget.done) return;
    HapticFeedback.lightImpact();
    widget.onPressed?.call();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final done = widget.done;
    final text = TextStyle(fontFamily: 'Nunito', fontSize: 16, fontWeight: FontWeight.w800, color: enabled ? Colors.white : StubColors.muted);

    Widget label = widget.busy
        ? _Dots(controller: _loop)
        : Padding(
            padding: EdgeInsets.symmetric(horizontal: 26),
            child: Text(widget.label, maxLines: 1, overflow: TextOverflow.fade, softWrap: false, style: text),
          );

    return LayoutBuilder(
      builder: (context, box) {
        final full = box.hasBoundedWidth ? box.maxWidth : null;
        return Semantics(
          button: true,
          enabled: enabled,
          label: widget.label,
          child: Align(
            child: AnimatedScale(
              scale: _down ? 0.95 : 1,
              duration: Duration(milliseconds: _down ? 90 : 380),
              curve: _down ? Curves.easeOut : Curves.elasticOut,
              child: AnimatedBuilder(
                animation: _loop,
                builder: (context, child) {
                  final t = _loop.value;
                  final breathe = 0.5 - 0.5 * math.cos(t * 2 * math.pi);
                  return AnimatedContainer(
                    duration: Duration(milliseconds: 450),
                    curve: Curves.easeInOutCubic,
                    width: done ? 54 : full,
                    height: 54,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(27),
                      color: done ? StubColors.owed : (enabled ? null : StubColors.soft),
                      gradient: done || !enabled
                          ? null
                          : LinearGradient(
                              begin: Alignment(-1 + t, -0.2),
                              end: Alignment(1 + t, 0.2),
                              colors: [StubColors.pop, Color(0xFFFF8F5A), StubColors.pop],
                              tileMode: TileMode.mirror,
                            ),
                      boxShadow: !enabled
                          ? const []
                          : [
                              BoxShadow(
                                color: (done ? StubColors.owed : StubColors.pop).withValues(alpha: _down ? 0.3 : 0.28 + 0.14 * breathe),
                                blurRadius: _down ? 10 : 18 + 8 * breathe,
                                offset: Offset(0, _down ? 4 : 9),
                              ),
                            ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(27),
                      child: Material(
                        type: MaterialType.transparency,
                        child: InkWell(
                          customBorder: StadiumBorder(),
                          splashColor: Colors.white.withValues(alpha: 0.4),
                          highlightColor: Colors.transparent,
                          onTap: enabled ? _tap : null,
                          onTapDown: enabled ? (_) => setState(() => _down = true) : null,
                          onTapUp: (_) => setState(() => _down = false),
                          onTapCancel: () => setState(() => _down = false),
                          child: Stack(
                        alignment: Alignment.center,
                        fit: full != null && !done ? StackFit.expand : StackFit.loose,
                        children: [
                          if (enabled && !done && _loop.isAnimating)
                            Positioned.fill(child: CustomPaint(painter: _Sheen(t))),
                          AnimatedSwitcher(
                            duration: Duration(milliseconds: 220),
                            child: done
                                ? TweenAnimationBuilder<double>(
                                    key: ValueKey('tick'),
                                    tween: Tween(begin: 0, end: 1),
                                    duration: Duration(milliseconds: 420),
                                    curve: Curves.easeOutCubic,
                                    builder: (context, v, _) => CustomPaint(size: Size(24, 24), painter: _Tick(v)),
                                  )
                                : Center(key: ValueKey(widget.busy), child: child!),
                          ),
                        ],
                      ),
                        ),
                      ),
                    ),
                  );
                },
                child: ExcludeSemantics(child: label),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A soft white band sweeping left to right across the first half of each loop.
class _Sheen extends CustomPainter {
  _Sheen(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final p = (t / 0.55).clamp(0.0, 1.0);
    if (p >= 1) return;
    final x = -size.width * 0.5 + p * size.width * 2;
    final band = size.width * 0.35;
    final rect = Rect.fromLTWH(x - band, 0, band * 2, size.height);
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [Colors.white.withValues(alpha: 0), Colors.white.withValues(alpha: 0.5), Colors.white.withValues(alpha: 0)],
      ).createShader(rect);
    canvas.save();
    canvas.translate(x, size.height / 2);
    canvas.skew(-0.35, 0);
    canvas.translate(-x, -size.height / 2);
    canvas.drawRect(rect, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_Sheen old) => old.t != t;
}

class _Tick extends CustomPainter {
  _Tick(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * 0.2, size.height * 0.52)
      ..lineTo(size.width * 0.42, size.height * 0.72)
      ..lineTo(size.width * 0.8, size.height * 0.3);
    final metric = path.computeMetrics().first;
    canvas.drawPath(
      metric.extractPath(0, metric.length * progress),
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.8
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_Tick old) => old.progress != progress;
}

class _Dots extends StatelessWidget {
  const _Dots({required this.controller});

  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 3; i++)
            Transform.translate(
              offset: Offset(0, -5 * math.max(0, math.sin((controller.value * 2 - i * 0.15) * 2 * math.pi))),
              child: Container(
                width: 6,
                height: 6,
                margin: EdgeInsets.symmetric(horizontal: 2.5),
                decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              ),
            ),
        ],
      ),
    );
  }
}

/// Every other action: see-through orange glass with a thin rim and a warm
/// tint slowly turning inside. Pressing brightens the rim, adds a halo, and
/// sends an orange ripple out from the finger.
class FrostButton extends StatefulWidget {
  const FrostButton({super.key, required this.label, required this.onPressed, this.icon, this.height = 50});

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final double height;

  @override
  State<FrostButton> createState() => _FrostButtonState();
}

class _FrostButtonState extends State<FrostButton> with SingleTickerProviderStateMixin {
  late final AnimationController _turn = AnimationController(vsync: this, duration: Duration(seconds: 7));
  bool _down = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (StubMotion.loops(context)) {
      _turn.repeat();
    } else {
      _turn.stop();
    }
  }

  @override
  void dispose() {
    _turn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final colour = enabled ? StubColors.pop : StubColors.muted;
    final radius = BorderRadius.circular(widget.height / 2);
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      child: AnimatedScale(
        scale: _down ? 0.96 : 1,
        duration: Duration(milliseconds: _down ? 90 : 380),
        curve: _down ? Curves.easeOut : Curves.elasticOut,
        child: AnimatedContainer(
          duration: Duration(milliseconds: 200),
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: radius,
            boxShadow: [if (_down) BoxShadow(color: StubColors.pop.withValues(alpha: 0.14), spreadRadius: 6, blurRadius: 0)],
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: AnimatedContainer(
                duration: Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: StubColors.pop.withValues(alpha: enabled ? 0.09 : 0.04),
                  borderRadius: radius,
                  border: Border.all(color: StubColors.pop.withValues(alpha: _down ? 0.75 : 0.38), width: _down ? 2 : 1.5),
                ),
                child: Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    borderRadius: radius,
                    splashColor: StubColors.pop.withValues(alpha: 0.22),
                    highlightColor: Colors.transparent,
                    onTap: enabled
                        ? () {
                            HapticFeedback.selectionClick();
                            widget.onPressed!();
                          }
                        : null,
                    onTapDown: enabled ? (_) => setState(() => _down = true) : null,
                    onTapUp: (_) => setState(() => _down = false),
                    onTapCancel: () => setState(() => _down = false),
                    child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (enabled)
                      AnimatedBuilder(
                        animation: _turn,
                        builder: (context, _) => ImageFiltered(
                          imageFilter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: SweepGradient(
                                transform: GradientRotation(_turn.value * 2 * math.pi),
                                colors: [
                                  Colors.transparent,
                                  StubColors.pop.withValues(alpha: 0.16),
                                  Colors.transparent,
                                  Color(0xFFFFAA78).withValues(alpha: 0.18),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ExcludeSemantics(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (widget.icon != null) ...[Icon(widget.icon, size: 18, color: colour), SizedBox(width: 7)],
                          Flexible(
                            child: Text(
                              widget.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontFamily: 'Nunito', fontSize: 15, fontWeight: FontWeight.w800, color: colour),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
