import 'package:material_ui/material_ui.dart';

import '../../app_model.dart';
import '../../core/money.dart';
import '../../core/tokens.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../../ui/kit/glass.dart';
import '../../ui/kit/kit.dart';
import '../../ui/kit/motion.dart';
import '../add/category_sheet.dart';

/// Adds a bill, or edits [bill] when given.
Future<void> showBillSheet(BuildContext context, {BillStatus? bill}) {
  return showGlassSheet<void>(context, (_) => BillSheet(bill: bill));
}

class BillSheet extends StatefulWidget {
  const BillSheet({super.key, this.bill});

  final BillStatus? bill;

  @override
  State<BillSheet> createState() => _BillSheetState();
}

class _BillSheetState extends State<BillSheet> {
  late final _amount = TextEditingController(text: widget.bill == null ? '' : '${widget.bill!.amount ~/ 100}');
  late final _name = TextEditingController(text: widget.bill?.name ?? '');
  late int _day = widget.bill?.dueDay ?? 1;
  late bool _autopay = widget.bill?.autopay ?? false;
  int? _categoryId;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _name.dispose();
    super.dispose();
  }

  void _save(List<Category> categories, int categoryId) {
    final amount = parseAmount(_amount.text);
    if (amount == null) {
      setState(() => _error = 'Type an amount, like 640');
      return;
    }
    final category = categories.firstWhere((c) => c.id == categoryId).name;
    final name = _name.text.trim().isEmpty ? category : _name.text.trim();
    final model = StubScope.of(context);
    final bill = widget.bill;
    model.write((s) {
      if (bill == null) {
        s.addBill(name: name, amount: amount, dueDay: _day, categoryId: categoryId, autopay: _autopay);
      } else {
        s.updateBill(bill.id, name: name, amount: amount, dueDay: _day, autopay: _autopay, categoryId: categoryId);
      }
      // A new autopay whose day has already come is logged straight away.
      s.runAutopays(model.today);
    });
    Navigator.of(context).pop();
  }

  void _stop() {
    final bill = widget.bill!;
    StubScope.of(context).write((s) => s.removeBill(bill.id));
    Navigator.of(context).pop();
  }

  Future<void> _pickDay() async {
    final picked = await showGlassSheet<int>(context, (context) => _DayGrid(selected: _day));
    if (picked != null && mounted) setState(() => _day = picked);
  }

  @override
  Widget build(BuildContext context) {
    final categories = StubScope.of(context).store.categories();
    final fallback = categories.where((c) => c.name == 'Rent').firstOrNull ?? categories.first;
    final categoryId = _categoryId ?? widget.bill?.categoryId ?? fallback.id;
    final category = categories.firstWhere((c) => c.id == categoryId, orElse: () => fallback).name;
    final keyboard = MediaQuery.of(context).viewInsets.bottom;
    const field = InputDecoration(border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none);

    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(StubSpace.gutter, 10, StubSpace.gutter, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SheetGrab(),
              Text(
                widget.bill == null ? 'New bill' : 'Edit bill',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: StubColors.ink),
              ),
              TextField(
                key: Key('bill-amount'),
                controller: _amount,
                autofocus: widget.bill == null,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                style: TextStyle(fontSize: 44, fontWeight: FontWeight.w900, color: StubColors.ink),
                decoration: field.copyWith(prefixText: '₹', hintText: '0', errorText: _error),
                onChanged: (_) => setState(() => _error = null),
              ),
              SizedBox(height: 8),
              SoftCard(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Column(
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: StubColors.soft,
                          child: Icon(Icons.edit_rounded, size: 17, color: StubColors.muted),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            key: Key('bill-name'),
                            controller: _name,
                            textCapitalization: TextCapitalization.sentences,
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: StubColors.ink),
                            decoration: field.copyWith(hintText: 'Name, like Electricity'),
                          ),
                        ),
                      ],
                    ),
                    Divider(height: 1, color: StubColors.line),
                    TapRow(
                      key: Key('bill-category'),
                      leading: CategoryIcon(category: category, radius: 18),
                      label: 'Category',
                      value: category,
                      onTap: () async {
                        final picked = await showCategorySheet(context, categories, categoryId);
                        if (picked != null && mounted) setState(() => _categoryId = picked);
                      },
                    ),
                    Divider(height: 1, color: StubColors.line),
                    TapRow(
                      key: Key('bill-day'),
                      leading: CircleAvatar(
                        radius: 18,
                        backgroundColor: StubColors.soft,
                        child: Icon(Icons.event_rounded, size: 18, color: StubColors.muted),
                      ),
                      label: 'Every month on',
                      value: _ordinal(_day),
                      onTap: _pickDay,
                    ),
                    Divider(height: 1, color: StubColors.line),
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: _autopay ? Color(0xFFFFF1E8) : StubColors.soft,
                            child: Icon(Icons.autorenew_rounded, size: 18, color: _autopay ? StubColors.pop : StubColors.muted),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Autopay', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: StubColors.ink)),
                                Text(
                                  _autopay ? 'Logged as a spend on its day' : 'You tick it when you pay',
                                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: StubColors.muted),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            key: Key('bill-autopay'),
                            value: _autopay,
                            activeTrackColor: StubColors.pop,
                            onChanged: (v) => setState(() => _autopay = v),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),
              PillButton(
                key: Key('bill-save'),
                label: widget.bill == null ? 'Add bill' : 'Save',
                onPressed: () => _save(categories, categoryId),
              ),
              if (widget.bill != null)
                TextButton(
                  key: Key('bill-stop'),
                  onPressed: _stop,
                  child: Text('Stop this bill', style: TextStyle(color: StubColors.owe, fontWeight: FontWeight.w800)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

String _ordinal(int day) {
  final suffix = (day >= 11 && day <= 13)
      ? 'th'
      : switch (day % 10) {
          1 => 'st',
          2 => 'nd',
          3 => 'rd',
          _ => 'th',
        };
  return '$day$suffix';
}

/// Days 1 to 31 in a calendar-like grid.
class _DayGrid extends StatelessWidget {
  const _DayGrid({required this.selected});

  final int selected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SheetGrab(),
            Text('Day of the month', style: Theme.of(context).textTheme.titleMedium),
            SizedBox(height: 4),
            Text('Later than the 28th? Short months use their last day.', style: Theme.of(context).textTheme.bodyMedium),
            SizedBox(height: 14),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 340),
              child: GridView.count(
              crossAxisCount: 7,
              shrinkWrap: true,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              physics: NeverScrollableScrollPhysics(),
              children: [
                for (var d = 1; d <= 31; d++)
                  Pressable(
                    key: Key('day-$d'),
                    scale: 0.85,
                    label: 'Day $d',
                    onTap: () => Navigator.of(context).pop(d),
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: d == selected ? StubColors.ink : StubColors.surface,
                      ),
                      child: ExcludeSemantics(
                        child: Text(
                          '$d',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: d == selected ? Colors.white : StubColors.ink,
                          ),
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
    );
  }
}
