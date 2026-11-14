import 'package:material_ui/material_ui.dart';

import '../../app_model.dart';
import '../../core/dates.dart';
import '../../core/money.dart';
import '../../core/tokens.dart';
import '../../data/store.dart';
import '../../ui/kit/glass.dart';
import '../../ui/kit/kit.dart';
import '../../ui/kit/paper.dart';
import 'category_sheet.dart';
import 'receipt_dialog.dart';
import 'split_draft.dart';
import 'split_sheet.dart';

/// A tall glass pop-up over Home: amount, note, category and split. Category and split each
/// open their own sheet so the form itself stays three rows long.
class AddSpendSheet extends StatefulWidget {
  const AddSpendSheet({super.key});

  @override
  State<AddSpendSheet> createState() => _AddSpendSheetState();
}

class _AddSpendSheetState extends State<AddSpendSheet> {
  final _amount = TextEditingController();
  final _title = TextEditingController();
  final _split = SplitDraft();
  int? _categoryId;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _title.dispose();
    super.dispose();
  }

  Future<void> _openSplit() async {
    await showGlassSheet<void>(context, (_) => SplitSheet(draft: _split, total: parseAmount(_amount.text)));
    if (mounted) setState(() => _error = null);
  }

  Future<void> _save() async {
    final model = StubScope.of(context);
    final store = model.store;
    final total = parseAmount(_amount.text);
    if (total == null) {
      setState(() => _error = 'Type an amount, like 120');
      return;
    }
    final split = _split.active ? _split.result(total) : null;
    if (split != null && !split.ok) {
      setState(() => _error = 'Split: ${_split.problem(total, split)}');
      return;
    }
    final categories = store.categories();
    final categoryId = _categoryId ?? categories.first.id;
    final category = categories.firstWhere((c) => c.id == categoryId).name;
    final title = _title.text.trim().isEmpty ? category : _title.text.trim();
    final names = {for (final f in store.friends()) f.id: f.name};
    final mine = split == null ? total : split.shares[me]!;
    final today = model.today;

    model.write(
      (s) => s.addSpend(
        title: title,
        total: total,
        categoryId: categoryId,
        day: today,
        friendShares: split == null ? const {} : {for (final id in _split.friends) id: split.shares['$id']!},
        payerFriendId: _split.active ? _split.payer : null,
      ),
    );

    await showDialog<void>(
      context: context,
      builder: (_) => ReceiptDialog(
        subtitle: '${weekdayShort(today)} ${today.day} ${monthShort(today)} ${today.year} · $category'.toUpperCase(),
        lines: [
          ReceiptLine.rule(),
          ReceiptLine(title, formatInr(total, decimals: true)),
          if (split != null) ...[
            for (final line in _split.debtLines(split, names)) ReceiptLine(line, ''),
            ReceiptLine('Your share', formatInr(mine, decimals: true)),
          ],
          ReceiptLine.rule(),
          ReceiptLine('Today so far', formatInr(store.spentOnDay(today), decimals: true)),
          ReceiptLine('LEFT', formatInr(store.budget - store.spentInMonth(today), decimals: true), bold: true),
        ],
      ),
    );
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final store = StubScope.of(context).store;
    final categories = store.categories();
    final names = {for (final f in store.friends()) f.id: f.name};
    _split.prune(names.keys.toSet());
    final categoryId = _categoryId ?? categories.first.id;
    final category = categories.firstWhere((c) => c.id == categoryId).name;

    final media = MediaQuery.of(context);
    final keyboard = media.viewInsets.bottom;
    final height = (media.size.height * 0.9 - keyboard).clamp(320.0, media.size.height);

    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: SizedBox(
        height: height,
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              SizedBox(height: 10),
              const SheetGrab(),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    IconButton(
                      key: Key('close-add'),
                      tooltip: 'Close',
                      icon: Icon(Icons.close_rounded, color: StubColors.muted),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    Expanded(
                      child: Text(
                        'New spend',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: StubColors.ink),
                      ),
                    ),
                    SizedBox(width: 48),
                  ],
                ),
              ),
              Expanded(child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(StubSpace.gutter, 8, StubSpace.gutter, 24),
        child: Column(
          children: [
            TextField(
              key: Key('amount-field'),
              controller: _amount,
              autofocus: true,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(fontSize: 52, fontWeight: FontWeight.w900, color: StubColors.ink),
              decoration: InputDecoration(prefixText: '₹', hintText: '0', border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none, errorText: _error),
              onChanged: (_) => setState(() {
                _error = null;
                if (_split.active) _split.prefill(parseAmount(_amount.text) ?? 0);
              }),
            ),
            SizedBox(height: 12),
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
                          key: Key('title-field'),
                          controller: _title,
                          textCapitalization: TextCapitalization.sentences,
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: StubColors.ink),
                          decoration: InputDecoration(hintText: 'What was it for?', border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none),
                        ),
                      ),
                    ],
                  ),
                  Divider(height: 1, color: StubColors.line),
                  _TapRow(
                    key: Key('category-row'),
                    leading: CategoryIcon(category: category, radius: 18),
                    label: 'Category',
                    value: category,
                    onTap: () async {
                      final picked = await showCategorySheet(context, categories, categoryId);
                      if (picked != null && mounted) setState(() => _categoryId = picked);
                    },
                  ),
                  Divider(height: 1, color: StubColors.line),
                  _TapRow(
                    key: Key('split-row'),
                    leading: CircleAvatar(
                      radius: 18,
                      backgroundColor: _split.active ? Color(0xFFFFF1E8) : StubColors.soft,
                      child: Icon(
                        Icons.group_rounded,
                        size: 18,
                        color: _split.active ? StubColors.pop : StubColors.muted,
                      ),
                    ),
                    label: 'Split',
                    value: _split.label(names),
                    onTap: _openSplit,
                  ),
                ],
              ),
            ),
          ],
        ),
      )),
              Padding(
                padding: EdgeInsets.fromLTRB(24, 6, 24, 14),
                child: PillButton(key: Key('save-button'), label: 'Add spend', onPressed: _save),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A form row that opens something: icon, label, current value, chevron.
class _TapRow extends StatelessWidget {
  const _TapRow({super.key, required this.leading, required this.label, required this.value, required this.onTap});

  final Widget leading;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            leading,
            SizedBox(width: 12),
            Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: StubColors.muted)),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: StubColors.ink),
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: StubColors.muted),
          ],
        ),
      ),
    );
  }
}
