import 'package:material_ui/material_ui.dart';

import '../../core/tokens.dart';
import '../../ui/kit/curled_receipt.dart';
import '../../ui/kit/paper.dart';

/// The printed stub shown after saving: curled 3D paper that feeds in from above.
class ReceiptDialog extends StatelessWidget {
  const ReceiptDialog({super.key, required this.lines, this.subtitle});

  final List<ReceiptLine> lines;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: Duration(milliseconds: 900),
              curve: Curves.easeOutQuart,
              builder: (context, t, child) => Opacity(
                opacity: (t * 2).clamp(0.0, 1.0).toDouble(),
                child: Transform.translate(
                  offset: Offset(0, -70 * (1 - t)),
                  child: Transform.scale(scale: 0.94 + 0.06 * t, child: child),
                ),
              ),
              child: RepaintBoundary(child: CurledReceipt(subtitle: subtitle, lines: lines)),
            ),
            SizedBox(height: 8),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: StubColors.ink,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: StadiumBorder(),
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Done'),
            ),
          ],
        ),
      ),
    );
  }
}
