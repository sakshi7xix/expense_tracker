import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../core/tokens.dart';
import 'paper.dart';

/// One horizontal strip of the receipt.
class _Strip {
  const _Strip(this.child, this.height, {this.torn = false});

  final Widget child;
  final double height;
  final bool torn;
}

/// A receipt built from thin strips of paper, each hinged to the one above,
/// so it really curls at the top and bottom. Every strip is shaded by how
/// far it has bent, and a soft shadow sits under the whole thing.
class CurledReceipt extends StatelessWidget {
  const CurledReceipt({
    super.key,
    required this.lines,
    this.subtitle,
    this.width = 250,
    this.tiltX = 0.16,
    this.tiltY = -0.26,
    this.tiltZ = 0.03,
    this.curlTop = 4,
    this.curlBottom = -6,
  });

  final List<ReceiptLine> lines;
  final String? subtitle;
  final double width;

  /// How the whole receipt is held, in radians.
  final double tiltX, tiltY, tiltZ;

  /// Bend per strip, in degrees, near the top and near the bottom.
  final double curlTop, curlBottom;

  static const _ink = Color(0xFF33333B);
  static const _faint = Color(0xFF7B7A82);

  List<_Strip> _strips() {
    final mono = receiptMono.copyWith(fontSize: 12, height: 1, color: _ink);
    Widget centred(String text, TextStyle style) => Center(child: Text(text, style: style));
    Widget row(String a, String b, {bool bold = false}) {
      final style = bold ? mono.copyWith(fontWeight: FontWeight.w500, color: StubColors.ink, fontSize: 13) : mono;
      return Row(
        children: [
          Expanded(child: Text(a, maxLines: 1, overflow: TextOverflow.ellipsis, style: style)),
          SizedBox(width: 10),
          Text(b, style: style),
        ],
      );
    }

    return [
      _Strip(SizedBox(), 10),
      _Strip(
        centred('STUB', TextStyle(fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: 4, color: StubColors.ink)),
        26,
      ),
      if (subtitle != null)
        _Strip(centred(subtitle!, mono.copyWith(fontSize: 9, letterSpacing: 0.8, color: _faint)), 16),
      for (final line in lines)
        if (line.isRule)
          _Strip(const DashedRule(), 14)
        else
          _Strip(row(line.label, line.value, bold: line.bold), 22),
      _Strip(SizedBox(), 6),
      _Strip(
        Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: CustomPaint(painter: BarcodePainter())),
        30,
      ),
      _Strip(centred('THANK YOU', mono.copyWith(fontSize: 9, letterSpacing: 1.5, color: _faint)), 20),
      _Strip(SizedBox(), 14, torn: true),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final strips = _strips();
    final n = strips.length;
    final angles = [
      for (var i = 0; i < n; i++)
        i == 0
            ? 0.0
            : i / (n - 1) < 0.22
                ? curlTop
                : i / (n - 1) > 0.72
                    ? curlBottom
                    : 0.0,
    ];
    final total = strips.fold<double>(0, (a, s) => a + s.height);

    // Build from the bottom strip up: each strip carries the rest below it.
    Widget? below;
    var bend = angles.fold<double>(0, (a, b) => a + b);
    for (var i = n - 1; i >= 0; i--) {
      final strip = strips[i];
      final light = (95.5 + bend * 0.28).clamp(86.0, 99.0) / 100;
      bend -= angles[i];
      final base = HSLColor.fromAHSL(1, 50, 0.08, light).toColor();
      Widget paper = Container(
        height: strip.height + 0.6,
        padding: EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color.lerp(base, Colors.black, 0.07)!,
              base,
              Color.lerp(base, Colors.white, 0.35)!,
              base,
              Color.lerp(base, Colors.black, 0.08)!,
            ],
            stops: [0, 0.09, 0.46, 0.8, 1],
          ),
        ),
        child: strip.child,
      );
      if (strip.torn) paper = ClipPath(clipper: const ZigzagClipper(tooth: 4), child: paper);
      final content = Column(
        mainAxisSize: MainAxisSize.min,
        children: [SizedBox(width: width, child: paper), ?below],
      );
      below = i == 0
          ? content
          : Transform(
              alignment: Alignment.topCenter,
              transform: Matrix4.identity()
                ..translateByDouble(0, -0.6, 0, 1)
                ..rotateX(angles[i] * math.pi / 180),
              child: content,
            );
    }

    return SizedBox(
      width: width + 40,
      height: total + 40,
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.0012)
          ..rotateX(tiltX)
          ..rotateY(tiltY)
          ..rotateZ(tiltZ),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            Positioned(
              top: 34,
              left: 26,
              right: 10,
              height: total - 26,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [BoxShadow(color: Color(0x551E1E28), blurRadius: 26, offset: Offset(6, 16))],
                ),
              ),
            ),
            Positioned(top: 20, child: below!),
          ],
        ),
      ),
    );
  }
}
