import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/tokens.dart';
import '../../ui/kit/curled_receipt.dart';
import '../../ui/kit/motion.dart';
import '../../ui/kit/paper.dart';

/// The printed stub shown after saving. The paper feeds out of a little
/// printer in short ticks (with a haptic tick for each), then drops free and
/// curls into its resting pose.
class ReceiptDialog extends StatefulWidget {
  const ReceiptDialog({super.key, required this.lines, this.subtitle});

  final List<ReceiptLine> lines;
  final String? subtitle;

  @override
  State<ReceiptDialog> createState() => _ReceiptDialogState();
}

class _ReceiptDialogState extends State<ReceiptDialog> with SingleTickerProviderStateMixin {
  static const _ticks = 14;
  static const _feedEnd = 0.6;

  late final AnimationController _c = AnimationController(vsync: this, duration: Duration(milliseconds: 1750));
  int _lastTick = -1;
  bool _landed = false;

  @override
  void initState() {
    super.initState();
    _c.addListener(_haptics);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (StubMotion.reduced(context)) {
      _c.value = 1;
    } else if (_c.value == 0 && !_c.isAnimating) {
      _c.forward();
    }
  }

  void _haptics() {
    final tick = (_feed * _ticks).floor();
    if (tick != _lastTick && tick < _ticks) {
      _lastTick = tick;
      HapticFeedback.selectionClick();
    }
    if (!_landed && _c.value >= _feedEnd) {
      _landed = true;
      HapticFeedback.mediumImpact();
    }
  }

  /// 0 to 1 while the paper feeds out, moving in short printer-like steps.
  double get _feed {
    final t = (_c.value / _feedEnd).clamp(0.0, 1.0);
    final steps = t * _ticks;
    final whole = steps.floorToDouble();
    return ((whole + Curves.easeOutCubic.transform(steps - whole)) / _ticks).clamp(0.0, 1.0);
  }

  /// 0 to 1 (with a little overshoot) as the paper drops free and curls.
  double get _settle {
    final t = ((_c.value - _feedEnd) / (1 - _feedEnd)).clamp(0.0, 1.0);
    return Curves.easeOutBack.transform(t);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final feed = _feed;
            final s = _settle;
            final printing = _c.value < _feedEnd;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Opacity(
                  opacity: (1 - s * 1.4).clamp(0.0, 1.0),
                  child: Transform.translate(
                    offset: Offset(0, -24 * s),
                    child: _Printer(lit: printing && (_lastTick.isEven)),
                  ),
                ),
                Transform.translate(
                  offset: Offset(0, 14 * s - 6),
                  child: ClipRect(
                    clipBehavior: s > 0 ? Clip.none : Clip.hardEdge,
                    child: FractionalTranslation(
                      translation: Offset(0, feed - 1),
                      child: RepaintBoundary(
                        child: CurledReceipt(
                          subtitle: widget.subtitle,
                          lines: widget.lines,
                          tiltX: 0.32 * s,
                          tiltY: -0.34 * s,
                          tiltZ: 0.04 * s,
                          curlTop: 7 * s,
                          curlBottom: -10 * s,
                        ),
                      ),
                    ),
                  ),
                ),
                Opacity(
                  opacity: ((_c.value - 0.75) / 0.25).clamp(0.0, 1.0),
                  child: Pressable(
                    scale: 0.94,
                    label: 'Done',
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 34, vertical: 14),
                      decoration: BoxDecoration(color: StubColors.ink, borderRadius: BorderRadius.circular(26)),
                      child: ExcludeSemantics(
                        child: Text(
                          'Done',
                          style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// A slim matte printer bar with a dark slot and a status light.
class _Printer extends StatelessWidget {
  const _Printer({required this.lit});

  final bool lit;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 286,
      height: 34,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(17),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF5A5B63), Color(0xFF2A2B30), Color(0xFF141416)],
        ),
        boxShadow: [BoxShadow(color: Color(0x66000000), blurRadius: 18, offset: Offset(0, 10))],
      ),
      child: Stack(
        children: [
          Positioned(
            left: 18,
            right: 18,
            bottom: 7,
            height: 4,
            child: DecoratedBox(
              decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Positioned(
            right: 18,
            top: 10,
            child: AnimatedContainer(
              duration: Duration(milliseconds: 90),
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: lit ? StubColors.pop : Color(0xFF7A3A1C),
                boxShadow: lit ? [BoxShadow(color: StubColors.pop, blurRadius: 8)] : const [],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
