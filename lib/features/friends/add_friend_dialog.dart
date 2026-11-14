import 'package:material_ui/material_ui.dart';

import '../../app_model.dart';
import '../../core/tokens.dart';
import '../../data/auth.dart';
import '../../data/store.dart';
import '../../ui/kit/glass.dart';
import '../../ui/kit/motion.dart';

/// Asks for a name and an optional phone or email, saves the friend and
/// returns their id, or null if cancelled.
Future<int?> showAddFriend(BuildContext context) {
  return showDialog<int>(context: context, barrierColor: glassBarrier, builder: (_) => _AddFriendDialog());
}

class _AddFriendDialog extends StatefulWidget {
  @override
  State<_AddFriendDialog> createState() => _AddFriendDialogState();
}

class _AddFriendDialogState extends State<_AddFriendDialog> {
  final _name = TextEditingController();
  final _contact = TextEditingController();
  String? _error;
  String? _emailError;

  @override
  void dispose() {
    _name.dispose();
    _contact.dispose();
    super.dispose();
  }

  void _save() {
    final email = _contact.text.trim();
    if (email.isNotEmpty && !looksLikeEmail(email)) {
      setState(() => _emailError = 'That email doesn’t look right');
      return;
    }
    try {
      final id = StubScope.of(context).write(
        (store) => store.addFriend(_name.text, contact: email.toLowerCase()),
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
    return GlassDialog(
      title: 'Add a friend',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: Key('friend-name-field'),
            controller: _name,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: StubColors.ink),
            decoration: InputDecoration(labelText: 'Name', errorText: _error),
          ),
          SizedBox(height: 6),
          TextField(
            controller: _contact,
            keyboardType: TextInputType.emailAddress,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: StubColors.ink),
            decoration: InputDecoration(
              labelText: 'Their email (optional)',
              helperText: 'So they’re linked to you when they join',
              errorText: _emailError,
            ),
            onChanged: (_) {
              if (_emailError != null) setState(() => _emailError = null);
            },
            onSubmitted: (_) => _save(),
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
          key: Key('friend-save'),
          scale: 0.94,
          label: 'Add',
          onTap: _save,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(color: StubColors.ink, borderRadius: BorderRadius.circular(22)),
            child: ExcludeSemantics(
              child: Text('Add', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
            ),
          ),
        ),
      ],
    );
  }
}
