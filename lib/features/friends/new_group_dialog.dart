import 'package:material_ui/material_ui.dart';

import '../../app_model.dart';
import '../../core/tokens.dart';
import '../../data/store.dart';
import '../../ui/kit/glass.dart';
import '../../ui/kit/kit.dart';
import '../../ui/kit/motion.dart';
import 'add_friend_dialog.dart';

/// Asks for a group name and who is in it, then saves the group.
Future<void> showNewGroup(BuildContext context) {
  return showDialog<void>(context: context, barrierColor: glassBarrier, builder: (_) => _NewGroupDialog());
}

class _NewGroupDialog extends StatefulWidget {
  @override
  State<_NewGroupDialog> createState() => _NewGroupDialogState();
}

class _NewGroupDialogState extends State<_NewGroupDialog> {
  final _name = TextEditingController();
  final _members = <int>{};
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Give the group a name');
      return;
    }
    if (_members.isEmpty) {
      setState(() => _error = 'Pick at least one friend');
      return;
    }
    StubScope.of(context).write((s) => s.addGroup(_name.text, _members.toList()));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final friends = StubScope.of(context).store.friends();
    return GlassDialog(
      title: 'New group',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            key: Key('group-name'),
            controller: _name,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: StubColors.ink),
            decoration: InputDecoration(labelText: 'Name, like Flatmates or Goa trip'),
          ),
          SizedBox(height: 14),
          Text('Who is in it', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: StubColors.muted)),
          SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final f in friends)
                ChoicePill(
                  key: Key('member-${f.id}'),
                  label: f.name,
                  selected: _members.contains(f.id),
                  onTap: () => setState(() {
                    _error = null;
                    _members.contains(f.id) ? _members.remove(f.id) : _members.add(f.id);
                  }),
                ),
              ChoicePill(
                key: Key('member-new'),
                label: '+ Friend',
                selected: false,
                onTap: () async {
                  final id = await showAddFriend(context);
                  if (id != null && mounted) setState(() => _members.add(id));
                },
              ),
            ],
          ),
          if (_error != null)
            Padding(
              padding: EdgeInsets.only(top: 10),
              child: Text(_error!, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: StubColors.owe)),
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
          key: Key('group-save'),
          scale: 0.94,
          label: 'Create',
          onTap: _save,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(color: StubColors.ink, borderRadius: BorderRadius.circular(22)),
            child: ExcludeSemantics(
              child: Text('Create', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
            ),
          ),
        ),
      ],
    );
  }
}
