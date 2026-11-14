import 'package:material_ui/material_ui.dart';

import '../../core/money.dart';
import '../../core/tokens.dart';
import '../../ui/kit/motion.dart';

/// One bar per week of the month against a dashed weekly-budget line. The
/// current week is ink, weeks over budget are a soft orange, later weeks are
/// empty stubs. Tap a bar to read its total underneath.
class WeekBars extends StatefulWidget {
  const WeekBars({super.key, required this.totals, required this.budget, required this.current});

  final List<int> totals;
  final int budget;
  final int current;

  @override
  State<WeekBars> createState() => _WeekBarsState();
}

class _WeekBarsState extends State<WeekBars> {
  int? _picked;

  static const _height = 92.0;

  @override
  Widget build(BuildContext context) {
    final totals = widget.totals;
    final top = [widget.budget, ...totals].reduce((a, b) => a > b ? a : b);
    double h(int v) => top <= 0 ? 0 : v / top * _height;
    final picked = (_picked ?? widget.current).clamp(0, totals.length - 1).toInt();
    final total = totals[picked];
    final over = total - widget.budget;
    final name = picked == widget.current ? 'This week' : 'Week ${picked + 1}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: _height + 22,
          child: Stack(
            children: [
              if (widget.budget > 0)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 22 + h(widget.budget),
                  child: CustomPaint(size: Size.fromHeight(1.5), painter: _Dashes()),
                ),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: StubMotion.reduced(context) ? 1 : 0, end: 1),
                duration: Duration(milliseconds: 800),
                curve: Curves.easeOutCubic,
                builder: (context, grow, _) => Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var i = 0; i < totals.length; i++)
                      Expanded(
                        child: GestureDetector(
                          key: Key('week-bar-$i'),
                          behavior: HitTestBehavior.opaque,
                          onTap: () => setState(() => _picked = i),
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 5),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Container(
                                  height: i > widget.current ? 4 : (h(totals[i]) * grow).clamp(4.0, _height),
                                  decoration: BoxDecoration(
                                    color: _colour(i),
                                    borderRadius: BorderRadius.circular(7),
                                    border: i == picked && i != widget.current
                                        ? Border.all(color: StubColors.ink, width: 1.5)
                                        : null,
                                  ),
                                ),
                                SizedBox(height: 6),
                                Text(
                                  'W${i + 1}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: i == picked ? StubColors.ink : StubColors.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 10),
        Text(
          widget.budget <= 0
              ? '$name · ${formatInr(total)}'
              : over > 0
                  ? '$name · ${formatInr(total)}, ${formatInr(over)} over'
                  : '$name · ${formatInr(total)} of ${formatInr(widget.budget)}',
          key: Key('week-caption'),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: over > 0 ? StubColors.popDark : StubColors.ink),
        ),
      ],
    );
  }

  Color _colour(int i) {
    if (i > widget.current) return StubColors.soft;
    if (i == widget.current) return StubColors.ink;
    if (widget.budget > 0 && widget.totals[i] > widget.budget) return Color(0xFFF3B49A);
    return Color(0xFFDCDBD7);
  }
}

class _Dashes extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Color(0xFFB9B8BE)
      ..strokeWidth = 1.5;
    for (var x = 0.0; x < size.width; x += 7) {
      canvas.drawLine(Offset(x, 0), Offset(x + 3.5, 0), paint);
    }
  }

  @override
  bool shouldRepaint(_Dashes oldDelegate) => false;
}
