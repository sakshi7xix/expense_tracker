import 'package:material_ui/material_ui.dart';

import '../../core/money.dart';
import '../../core/tokens.dart';
import '../../data/models.dart';
import '../../ui/kit/kit.dart';
import '../../ui/kit/motion.dart';

/// A small card for a bill that is still due this month.
class BillChip extends StatelessWidget {
  const BillChip({super.key, required this.bill, required this.category, required this.note, this.onTap});

  final BillStatus bill;
  final String category;
  final String note;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final overdue = note.startsWith('Overdue') || note == 'Due today';
    return Pressable(
      key: Key('coming-${bill.id}'),
      scale: 0.95,
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.fromLTRB(10, 8, 14, 8),
        decoration: BoxDecoration(
          color: StubColors.surface,
          borderRadius: BorderRadius.circular(StubRadius.row),
          boxShadow: [BoxShadow(color: Color(0x0A1E1E28), blurRadius: 10, offset: Offset(0, 3))],
        ),
        child: Row(
          children: [
            CategoryIcon(category: category, radius: 16),
            SizedBox(width: 9),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${bill.name} · ${formatInr(bill.amount)}',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: StubColors.ink),
                ),
                Text(
                  note,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: overdue ? StubColors.pop : StubColors.muted,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
