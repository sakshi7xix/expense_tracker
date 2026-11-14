import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

/// Shared motion values so every screen moves the same way.
abstract final class StubMotion {
  static const quick = Duration(milliseconds: 160);
  static const base = Duration(milliseconds: 320);
  static const slow = Duration(milliseconds: 520);
  static const enter = Curves.easeOutCubic;
  static const settle = Curves.easeOutBack;

  /// True when the person has asked the phone for less motion.
  static bool reduced(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;
}

/// Anything tappable: shrinks a little under the finger, leans toward where it
/// was touched when [tilt] is on, springs back, and gives a light tap of haptics.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = 0.96,
    this.tilt = false,
    this.haptic = true,
    this.label,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;
  final bool tilt;
  final bool haptic;
  final String? label;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;
  Offset _lean = Offset.zero;

  void _press(TapDownDetails d) {
    final box = context.findRenderObject() as RenderBox?;
    var lean = Offset.zero;
    if (widget.tilt && box != null && box.hasSize) {
      final s = box.size;
      lean = Offset(d.localPosition.dx / s.width - 0.5, d.localPosition.dy / s.height - 0.5);
    }
    setState(() {
      _down = true;
      _lean = lean;
    });
  }

  void _release() {
    if (_down) setState(() => _down = false);
  }

  @override
  Widget build(BuildContext context) {
    final still = StubMotion.reduced(context);
    final scale = _down && !still ? widget.scale : 1.0;
    final lean = _down && !still ? _lean : Offset.zero;
    return Semantics(
      button: widget.onTap != null,
      label: widget.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: widget.onTap == null && widget.onLongPress == null ? null : _press,
        onTapUp: (_) => _release(),
        onTapCancel: _release,
        onTap: widget.onTap == null
            ? null
            : () {
                if (widget.haptic) HapticFeedback.selectionClick();
                widget.onTap!();
              },
        onLongPress: widget.onLongPress == null
            ? null
            : () {
                _release();
                HapticFeedback.mediumImpact();
                widget.onLongPress!();
              },
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: scale),
          duration: _down ? Duration(milliseconds: 90) : Duration(milliseconds: 420),
          curve: _down ? Curves.easeOut : Curves.elasticOut,
          builder: (context, s, child) => TweenAnimationBuilder<Offset>(
            tween: Tween(end: lean),
            duration: Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            builder: (context, l, child) => Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateX(-l.dy * 0.12)
                ..rotateY(l.dx * 0.12)
                ..scaleByDouble(s, s, 1, 1),
              child: child,
            ),
            child: child,
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

/// Fades and rises its child into place once, [index] steps after the screen
/// opens, so lists build up one row after another instead of popping in.
class Entrance extends StatefulWidget {
  const Entrance({super.key, required this.child, this.index = 0, this.rise = 18});

  final Widget child;
  final int index;
  final double rise;

  @override
  State<Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<Entrance> with SingleTickerProviderStateMixin {
  static const _step = 45;
  static const _length = 440;
  late final int _delay = math.min(widget.index, 9) * _step;
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: _delay + _length),
  );
  late final Animation<double> _t = CurvedAnimation(
    parent: _c,
    curve: Interval(_delay / (_delay + _length), 1, curve: Curves.easeOutCubic),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (StubMotion.reduced(context)) {
      _c.value = 1;
    } else if (!_c.isAnimating && _c.value == 0) {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _t,
      builder: (context, child) => Opacity(
        opacity: _t.value,
        child: Transform.translate(offset: Offset(0, widget.rise * (1 - _t.value)), child: child),
      ),
      child: widget.child,
    );
  }
}

/// Opening a full screen from a button: it grows out of the bottom right,
/// where the + sits, and shrinks back there when closed.
class GrowRoute<T> extends PageRouteBuilder<T> {
  GrowRoute({required WidgetBuilder builder, Alignment from = Alignment.bottomRight})
      : super(
          transitionDuration: Duration(milliseconds: 460),
          reverseTransitionDuration: Duration(milliseconds: 320),
          pageBuilder: (context, a, b) => builder(context),
          transitionsBuilder: (context, animation, secondary, child) {
            final t = CurvedAnimation(parent: animation, curve: Curves.easeOutQuart, reverseCurve: Curves.easeInCubic);
            return FadeTransition(
              opacity: CurvedAnimation(parent: animation, curve: Interval(0, 0.55)),
              child: ScaleTransition(
                alignment: from,
                scale: Tween(begin: 0.86, end: 1.0).animate(t),
                child: AnimatedBuilder(
                  animation: t,
                  builder: (context, child) => ClipRRect(
                    borderRadius: BorderRadius.circular(28 * (1 - t.value)),
                    child: child,
                  ),
                  child: child,
                ),
              ),
            );
          },
        );
}
