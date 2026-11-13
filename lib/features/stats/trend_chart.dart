import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../core/money.dart';
import '../../core/tokens.dart';

/// One smooth line. The selected point gets a dot, a dashed drop line and a
/// tooltip with its amount. Tap or drag to move the selection.
class TrendChart extends StatelessWidget {
  const TrendChart({
    super.key,
    required this.values,
    required this.labels,
    required this.selected,
    required this.onSelect,
    this.fromZero = true,
  });

  /// Paise per point.
  final List<int> values;

  /// One label per point; empty strings are skipped.
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelect;

  /// When false the scale starts just under the smallest value, which makes
  /// differences between similar months visible.
  final bool fromZero;

  static const _pad = 16.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final width = box.maxWidth;
        void pick(double dx) {
          if (values.length < 2) return;
          final t = (dx - _pad) / (width - _pad * 2);
          onSelect((t * (values.length - 1)).round().clamp(0, values.length - 1).toInt());
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => pick(d.localPosition.dx),
          onHorizontalDragUpdate: (d) => pick(d.localPosition.dx),
          child: CustomPaint(
            size: Size(width, 200),
            painter: _TrendPainter(values, labels, selected, fromZero),
          ),
        );
      },
    );
  }
}

class _TrendPainter extends CustomPainter {
  _TrendPainter(this.values, this.labels, this.selected, this.fromZero);

  final List<int> values;
  final List<String> labels;
  final int selected;
  final bool fromZero;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    const pad = TrendChart._pad;
    const top = 46.0;
    final bottom = size.height - 26;
    final n = values.length;
    final high = math.max(1, values.reduce(math.max)) * 1.08;
    final low = fromZero ? 0.0 : values.reduce(math.min) * 0.86;
    double x(int i) => n == 1 ? size.width / 2 : pad + i / (n - 1) * (size.width - pad * 2);
    double y(int v) => bottom - (v - low) / (high - low) * (bottom - top);
    final points = [for (var i = 0; i < n; i++) Offset(x(i), y(values[i]))];

    final path = Path()..moveTo(points[0].dx, points[0].dy);
    final ease = n > 12 ? 8.0 : 5.0;
    for (var i = 0; i < n - 1; i++) {
      final before = points[math.max(0, i - 1)];
      final from = points[i];
      final to = points[i + 1];
      final after = points[math.min(n - 1, i + 2)];
      path.cubicTo(
        from.dx + (to.dx - before.dx) / ease,
        math.min(bottom, from.dy + (to.dy - before.dy) / ease),
        to.dx - (after.dx - from.dx) / ease,
        math.min(bottom, to.dy - (after.dy - from.dy) / ease),
        to.dx,
        to.dy,
      );
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = StubColors.ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    final index = selected.clamp(0, n - 1).toInt();
    final point = points[index];
    final dash = Paint()
      ..color = Color(0xFF9A99A0)
      ..strokeWidth = 1.2;
    for (double dy = point.dy + 9; dy < bottom + 6; dy += 7) {
      canvas.drawLine(Offset(point.dx, dy), Offset(point.dx, math.min(dy + 3, bottom + 6)), dash);
    }

    final tip = TextPainter(
      text: TextSpan(
        text: formatInr(values[index]),
        style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w800, fontFamily: 'Nunito'),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final bubbleWidth = tip.width + 18;
    final left = (point.dx - bubbleWidth / 2).clamp(2.0, size.width - bubbleWidth - 2).toDouble();
    final bubbleTop = math.max(2.0, point.dy - 38);
    final ink = Paint()..color = StubColors.ink;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(left, bubbleTop, bubbleWidth, 24), Radius.circular(8)),
      ink,
    );
    canvas.drawPath(
      Path()
        ..moveTo(point.dx - 5, bubbleTop + 23)
        ..lineTo(point.dx + 5, bubbleTop + 23)
        ..lineTo(point.dx, bubbleTop + 29)
        ..close(),
      ink,
    );
    tip.paint(canvas, Offset(left + 9, bubbleTop + (24 - tip.height) / 2));

    canvas.drawCircle(point, 6.5, Paint()..color = Colors.white);
    canvas.drawCircle(point, 4.6, Paint()..color = StubColors.pop);

    for (var i = 0; i < n && i < labels.length; i++) {
      if (labels[i].isEmpty) continue;
      final label = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: TextStyle(
            fontSize: 10.5,
            fontFamily: 'Nunito',
            fontWeight: i == index ? FontWeight.w800 : FontWeight.w700,
            color: i == index ? StubColors.ink : Color(0xFF9A99A0),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final lx = (x(i) - label.width / 2).clamp(0.0, size.width - label.width).toDouble();
      label.paint(canvas, Offset(lx, size.height - 14));
    }
  }

  @override
  bool shouldRepaint(_TrendPainter old) =>
      old.values != values || old.selected != selected || old.labels != labels || old.fromZero != fromZero;
}
