import 'package:material_ui/material_ui.dart';

import '../../core/tokens.dart';

/// The printed stub shown after saving. A plain receipt for now; the 3D
/// paper from the prototype comes with the design-kit phase.
class ReceiptDialog extends StatelessWidget {
  const ReceiptDialog({super.key, required this.lines});

  /// Label and value pairs, top to bottom. A null value draws a rule.
  final List<(String, String?)> lines;

  @override
  Widget build(BuildContext context) {
    final mono = TextStyle(fontFamily: 'monospace', fontSize: 13, color: StubColors.ink);
    return AlertDialog(
      backgroundColor: Color(0xFFFCFCFA),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      title: Center(
        child: Text('STUB', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 4, fontSize: 16)),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (label, value) in lines)
            if (value == null)
              Divider(height: 18, color: StubColors.muted)
            else
              Padding(
                padding: EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(child: Text(label, style: mono, overflow: TextOverflow.ellipsis)),
                    SizedBox(width: 12),
                    Text(value, style: mono),
                  ],
                ),
              ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text('Done')),
      ],
    );
  }
}
