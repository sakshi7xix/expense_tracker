import 'package:material_ui/material_ui.dart';

import '../../core/tokens.dart';

/// Bilby's mark: one charcoal line drawing a receipt with bilby ears, and an
/// orange dot for the nose. [ears] tilts the ears (radians) so they can wiggle.
class BilbyMark extends StatelessWidget {
  const BilbyMark({super.key, this.size = 64, this.ears = 0, this.background = true, this.color = StubColors.ink});

  final double size;
  final double ears;

  /// Draw the cream rounded square behind it, as on the app icon.
  final bool background;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _MarkPainter(ears: ears, background: background, color: color)),
    );
  }
}

const bilbyCream = Color(0xFFF6F1EA);

class _MarkPainter extends CustomPainter {
  _MarkPainter({required this.ears, required this.background, required this.color});

  final double ears;
  final bool background;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 100);
    if (background) {
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, 100, 100), Radius.circular(23)), Paint()..color = bilbyCream);
    }
    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    void ear(Offset pivot, Path path, double tilt) {
      canvas.save();
      canvas.translate(pivot.dx, pivot.dy);
      canvas.rotate(tilt);
      canvas.translate(-pivot.dx, -pivot.dy);
      canvas.drawPath(path, line);
      canvas.restore();
    }

    ear(Offset(41, 32), Path()..moveTo(35, 33)..cubicTo(35, 23, 37, 14, 40, 11)..cubicTo(43, 14, 46, 22, 46, 31), -ears);
    ear(Offset(59, 32), Path()..moveTo(54, 31)..cubicTo(54, 22, 57, 14, 60, 11)..cubicTo(63, 14, 65, 23, 65, 33), ears);

    final body = Path()..moveTo(33, 33)..lineTo(67, 33)..lineTo(67, 78);
    const step = 34 / 5;
    for (var x = 67.0; x > 33.01; x -= step) {
      body
        ..lineTo(x - step / 2, 83)
        ..lineTo(x - step, 78);
    }
    body.close();
    canvas.drawPath(body, line);
    canvas.drawLine(Offset(41, 61), Offset(59, 61), line);
    canvas.drawLine(Offset(41, 68), Offset(53, 68), line);

    final dot = Paint()..color = color;
    canvas.drawCircle(Offset(44, 47), 2.3, dot);
    canvas.drawCircle(Offset(56, 47), 2.3, dot);
    canvas.drawCircle(Offset(50, 53), 2.8, Paint()..color = StubColors.pop);
  }

  @override
  bool shouldRepaint(_MarkPainter old) => old.ears != ears || old.background != background || old.color != color;
}
