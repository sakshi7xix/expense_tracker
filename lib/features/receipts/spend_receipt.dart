import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../app_model.dart';
import '../../core/dates.dart';
import '../../core/money.dart';
import '../../core/tokens.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../../ui/kit/curled_receipt.dart';
import '../../ui/kit/motion.dart';
import '../../ui/kit/paper.dart';
import '../../ui/kit/glass.dart';
import '../add/add_spend_sheet.dart';

/// The lines printed on one spend's receipt.
List<ReceiptLine> spendLines(Entry entry, Map<String, int> split) {
  String money(int paise) => formatInr(paise, decimals: true);
  return [
    ReceiptLine.rule(),
    ReceiptLine(entry.title, money(entry.total)),
    for (final MapEntry(key: name, value: amount) in split.entries)
      amount > 0 ? ReceiptLine('$name owes you', money(amount)) : ReceiptLine('You owe $name', money(-amount)),
    if (entry.isAutopay) ReceiptLine('Paid by autopay', ''),
    ReceiptLine.rule(),
    ReceiptLine(entry.isSplit ? 'YOUR SHARE' : 'TOTAL', money(entry.amount), bold: true),
  ];
}

String _subtitle(Entry entry, String category) {
  final d = DateTime.parse(entry.day);
  return '${weekdayShort(d)} ${d.day} ${monthShort(d)} ${d.year} · $category'.toUpperCase();
}

/// Opens a spend as its receipt over a frosted page, with Edit, Copy and Delete.
Future<void> showSpendReceipt(BuildContext context, Entry entry, String category) {
  final model = StubScope.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final lines = spendLines(entry, model.store.splitOf(entry.id));
  // A shared spend a friend added can only be changed or deleted by them.
  final addedBy = entry.addedBy == null
      ? null
      : model.store.friends().where((f) => model.store.userOfFriend(f.id) == entry.addedBy).firstOrNull?.name ?? 'a friend';
  HapticFeedback.lightImpact();

  void delete(BuildContext dialog) {
    Navigator.of(dialog).pop();
    model.write((s) => s.deleteSpend(entry.id));
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Deleted ${entry.title}'),
          // A message with a button stays until tapped unless told otherwise.
          persist: false,
          duration: Duration(seconds: 4),
          action: SnackBarAction(label: 'Undo', onPressed: () => model.write((s) => s.restoreSpend(entry.id))),
        ),
      );
  }

  void copy(BuildContext dialog) {
    final text = [
      'RECEIPT · ${_subtitle(entry, category)}',
      for (final l in lines)
        if (!l.isRule) '${l.label}  ${l.value}'.trim(),
    ].join('\n');
    Navigator.of(dialog).pop();
    Clipboard.setData(ClipboardData(text: text));
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('Receipt copied')));
  }

  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close receipt',
    barrierColor: Colors.transparent,
    transitionDuration: Duration(milliseconds: 280),
    transitionBuilder: (context, animation, _, child) {
      final t = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(opacity: t, child: child);
    },
    pageBuilder: (dialog, animation, _) => Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: () => Navigator.of(dialog).pop(),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: ColoredBox(color: Color(0x99F3F2EF)),
            ),
          ),
        ),
        SafeArea(
          child: Stack(
            children: [
              Positioned(
                top: 8,
                right: 12,
                child: Pressable(
                  key: Key('receipt-close'),
                  scale: 0.9,
                  label: 'Close',
                  onTap: () => Navigator.of(dialog).pop(),
                  child: CircleAvatar(
                    radius: 19,
                    backgroundColor: StubColors.surface,
                    child: Icon(Icons.close_rounded, size: 20, color: StubColors.ink),
                  ),
                ),
              ),
              Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(vertical: 56),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // The receipt lifts off the page and curls as it opens.
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: StubMotion.reduced(dialog) ? 1 : 0, end: 1),
                        duration: Duration(milliseconds: 700),
                        curve: Curves.easeOutBack,
                        builder: (context, s, _) => Transform.translate(
                          offset: Offset(0, 30 * (1 - s)),
                          child: CurledReceipt(
                            lines: lines,
                            subtitle: _subtitle(entry, category),
                            tiltX: 0.32 * s,
                            tiltY: -0.34 * s,
                            tiltZ: 0.04 * s,
                            curlTop: 7 * s,
                            curlBottom: -10 * s,
                          ),
                        ),
                      ),
                      SizedBox(height: 28),
                      if (addedBy != null)
                        Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: Text('Added by $addedBy. Only they can change it.',
                              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: StubColors.muted, decoration: TextDecoration.none)),
                        ),
                      Material(
                        type: MaterialType.transparency,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (addedBy == null) ...[
                            _Action(
                              key: Key('receipt-edit'),
                              icon: Icons.edit_rounded,
                              label: 'Edit',
                              onTap: () {
                                Navigator.of(dialog).pop();
                                showGlassSheet<void>(context, (_) => AddSpendSheet(editing: entry));
                              },
                            ),
                            SizedBox(width: 8),
                            ],
                            _Action(key: Key('receipt-copy'), icon: Icons.copy_rounded, label: 'Copy', onTap: () => copy(dialog)),
                            if (addedBy == null) ...[
                            SizedBox(width: 8),
                            _Action(
                              key: Key('receipt-delete'),
                              icon: Icons.delete_outline_rounded,
                              label: 'Delete',
                              color: StubColors.owe,
                              onTap: () => delete(dialog),
                            ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _Action extends StatelessWidget {
  const _Action({super.key, required this.icon, required this.label, required this.onTap, this.color = StubColors.ink});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      scale: 0.92,
      label: label,
      onTap: onTap,
      child: Container(
        height: 44,
        padding: EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: StubColors.surface,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [BoxShadow(color: Color(0x0F1E1E28), blurRadius: 10, offset: Offset(0, 3))],
        ),
        child: ExcludeSemantics(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: color),
              SizedBox(width: 6),
              Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}
