import 'package:material_ui/material_ui.dart';

import '../../app_model.dart';
import '../../core/tokens.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../../ui/kit/glass.dart';
import '../../ui/kit/kit.dart';
import '../../ui/kit/motion.dart';
import '../add/category_sheet.dart';

/// Renames a spend or moves it to another category. Changing the amount or
/// the split means deleting it and adding it again, for now.
Future<void> showEditSpendDialog(BuildContext context, Entry entry) {
  return showDialog<void>(context: context, barrierColor: glassBarrier, builder: (_) => _EditSpendDialog(entry: entry));
}

class _EditSpendDialog extends StatefulWidget {
  const _EditSpendDialog({required this.entry});

  final Entry entry;

  @override
  State<_EditSpendDialog> createState() => _EditSpendDialogState();
}

class _EditSpendDialogState extends State<_EditSpendDialog> {
  late final _title = TextEditingController(text: widget.entry.title);
  late int _categoryId = widget.entry.categoryId;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  void _save(String category) {
    final title = _title.text.trim().isEmpty ? category : _title.text.trim();
    StubScope.of(context).write((s) => s.renameSpend(widget.entry.id, title: title, categoryId: _categoryId));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final categories = StubScope.of(context).store.categories();
    final category = categories.firstWhere((c) => c.id == _categoryId, orElse: () => categories.first).name;
    return GlassDialog(
      title: 'Edit spend',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: Key('edit-title'),
            controller: _title,
            textCapitalization: TextCapitalization.sentences,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: StubColors.ink),
            decoration: InputDecoration(labelText: 'What was it for?'),
          ),
          SizedBox(height: 4),
          TapRow(
            key: Key('edit-category'),
            leading: CategoryIcon(category: category, radius: 16),
            label: 'Category',
            value: category,
            onTap: () async {
              final picked = await showCategorySheet(context, categories, _categoryId);
              if (picked != null && mounted) setState(() => _categoryId = picked);
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(foregroundColor: StubColors.muted),
          child: Text('Cancel', style: TextStyle(fontWeight: FontWeight.w800)),
        ),
        SizedBox(width: 6),
        Pressable(
          key: Key('edit-save'),
          scale: 0.94,
          label: 'Save',
          onTap: () => _save(category),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(color: StubColors.ink, borderRadius: BorderRadius.circular(22)),
            child: ExcludeSemantics(
              child: Text('Save', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
            ),
          ),
        ),
      ],
    );
  }
}
