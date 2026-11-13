import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../core/tokens.dart';

/// Cuts a torn, zigzag edge along the bottom of a receipt.
class ZigzagClipper extends CustomClipper<Path> {
  const ZigzagClipper({this.tooth = 5});

  final double tooth;

  @override
  Path getClip(Size size) {
    final count = math.max(1, (size.width / (tooth * 2)).floor());
    final step = size.width / count;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height - tooth);
    for (var i = 0; i < count; i++) {
      final x = size.width - i * step;
      path
        ..lineTo(x - step / 2, size.height)
        ..lineTo(x - step, size.height - tooth);
    }
    return path..close();
  }

  @override
  bool shouldReclip(ZigzagClipper oldClipper) => oldClipper.tooth != tooth;
}

/// Receipt paper: off-white with soft shading across it, a torn bottom edge
/// and a shadow that follows the tear.
class Paper extends StatelessWidget {
  const Paper({
    super.key,
    required this.child,
    this.elevation = 10,
    this.padding = const EdgeInsets.fromLTRB(18, 18, 18, 22),
  });

  final Widget child;
  final double elevation;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return PhysicalShape(
      clipper: const ZigzagClipper(),
      clipBehavior: Clip.antiAlias,
      color: Color(0xFFFAFAF7),
      elevation: elevation,
      shadowColor: Color(0xAA1E1E28),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF1F0EC), Color(0xFFFCFCFA), Color(0xFFF6F5F1), Color(0xFFFDFDFB), Color(0xFFE9E8E3)],
            stops: [0, 0.12, 0.46, 0.6, 1],
          ),
        ),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Leans its child back and to one side, like paper held in the hand.
class Tilted extends StatelessWidget {
  const Tilted({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.0012)
        ..rotateX(0.16)
        ..rotateY(-0.22)
        ..rotateZ(0.03),
      child: child,
    );
  }
}

const receiptMono = TextStyle(
  fontFamily: 'IBMPlexMono',
  fontSize: 12.5,
  height: 1.7,
  color: Color(0xFF33333B),
);

class ReceiptLine {
  const ReceiptLine(this.label, this.value, {this.bold = false}) : isRule = false;
  const ReceiptLine.rule()
      : label = '',
        value = '',
        bold = false,
        isRule = true;

  final String label;
  final String value;
  final bool bold;
  final bool isRule;
}

/// The printed content of a stub: heading, lines, optional barcode.
class ReceiptView extends StatelessWidget {
  const ReceiptView({
    super.key,
    required this.lines,
    this.title = 'STUB',
    this.subtitle,
    this.barcode = true,
  });

  final String title;
  final String? subtitle;
  final List<ReceiptLine> lines;
  final bool barcode;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: 4, color: StubColors.ink),
        ),
        if (subtitle != null)
          Text(
            subtitle!,
            textAlign: TextAlign.center,
            style: receiptMono.copyWith(fontSize: 10, letterSpacing: 0.8, color: Color(0xFF7B7A82)),
          ),
        for (final line in lines)
          if (line.isRule)
            const DashedRule()
          else
            Row(
              children: [
                Expanded(
                  child: Text(
                    line.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: line.bold ? receiptMono.copyWith(fontWeight: FontWeight.w500, color: StubColors.ink) : receiptMono,
                  ),
                ),
                SizedBox(width: 10),
                Text(
                  line.value,
                  style: line.bold ? receiptMono.copyWith(fontWeight: FontWeight.w500, color: StubColors.ink) : receiptMono,
                ),
              ],
            ),
        if (barcode) ...[
          SizedBox(height: 12),
          SizedBox(height: 30, child: CustomPaint(painter: _BarcodePainter())),
          SizedBox(height: 6),
          Text(
            'THANK YOU',
            textAlign: TextAlign.center,
            style: receiptMono.copyWith(fontSize: 9.5, letterSpacing: 1.5, color: Color(0xFF7B7A82)),
          ),
        ],
      ],
    );
  }
}

class DashedRule extends StatelessWidget {
  const DashedRule({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(height: 16, child: CustomPaint(painter: _DashPainter()));
  }
}

class _DashPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Color(0xFFB9B8BE)
      ..strokeWidth = 1;
    final y = size.height / 2;
    for (double x = 0; x < size.width; x += 6) {
      canvas.drawLine(Offset(x, y), Offset(math.min(x + 3, size.width), y), paint);
    }
  }

  @override
  bool shouldRepaint(_DashPainter oldDelegate) => false;
}

class _BarcodePainter extends CustomPainter {
  static const _bars = [2.0, 1.0, 1.0, 2.0, 3.0, 1.0, 1.0, 1.0, 2.0, 1.0];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Color(0xD92B2B33);
    final inset = size.width * 0.12;
    var x = inset;
    var i = 0;
    while (x < size.width - inset) {
      final w = _bars[i % _bars.length];
      if (i.isEven) canvas.drawRect(Rect.fromLTWH(x, 0, w, size.height), paint);
      x += w;
      i++;
    }
  }

  @override
  bool shouldRepaint(_BarcodePainter oldDelegate) => false;
}
