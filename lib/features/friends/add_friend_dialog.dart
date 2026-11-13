import 'package:material_ui/material_ui.dart';

import '../../app_model.dart';
import '../../data/store.dart';

/// Asks for a name and an optional phone or email, saves the friend and
/// returns their id, or null if cancelled.
Future<int?> showAddFriend(BuildContext context) {
  return showDialog<int>(context: context, builder: (_) => _AddFriendDialog());
}

class _AddFriendDialog extends StatefulWidget {
  @override
  State<_AddFriendDialog> createState() => _AddFriendDialogState();
}

class _AddFriendDialogState extends State<_AddFriendDialog> {
  final _name = TextEditingController();
  final _contact = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _contact.dispose();
    super.dispose();
  }

  void _save() {
    try {
      final id = StubScope.of(context).write(
        (store) => store.addFriend(_name.text, contact: _contact.text),
      );
      Navigator.of(context).pop(id);
    } on ArgumentError {
      setState(() => _error = 'Add their name');
    } on StateError {
      setState(() => _error = '${_name.text.trim()} is already in your friends');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Add a friend'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: Key('friend-name-field'),
            controller: _name,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(labelText: 'Name', errorText: _error),
          ),
          TextField(
            controller: _contact,
            decoration: InputDecoration(labelText: 'Phone or email (optional)'),
            onSubmitted: (_) => _save(),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text('Cancel')),
        FilledButton(key: Key('friend-save'), onPressed: _save, child: Text('Add')),
      ],
    );
  }
}
