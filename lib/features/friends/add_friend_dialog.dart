import 'package:material_ui/material_ui.dart';

import '../../app_model.dart';
import '../../core/tokens.dart';
import '../../data/auth.dart';
import '../../data/store.dart';
import '../../ui/kit/glass.dart';
import '../../ui/kit/kit.dart';
import 'invite.dart';

/// Asks for a name and an optional email, saves the friend and returns
/// their id, or null if cancelled. "Add and invite" then shares an invite.
Future<int?> showAddFriend(BuildContext context) async {
  final result = await showDialog<(int, bool)>(context: context, barrierColor: glassBarrier, builder: (_) => _AddFriendDialog());
  if (result == null) return null;
  if (result.$2 && context.mounted) await inviteFriend(context, result.$1);
  return result.$1;
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

  void _save({bool invite = false}) {
    final email = _contact.text.trim();
    if (email.isNotEmpty && !looksLikeEmail(email)) {
      setState(() => _emailError = 'That email doesn’t look right');
      return;
    }
    try {
      final id = StubScope.of(context).write(
        (store) => store.addFriend(_name.text, contact: email.toLowerCase()),
      );
      Navigator.of(context).pop((id, invite));
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
          SizedBox(height: 18),
          PillButton(key: Key('friend-invite'), label: 'Add and invite', onPressed: () => _save(invite: true)),
          SizedBox(height: 8),
          FrostButton(key: Key('friend-save'), label: 'Just add', onPressed: _save),
        ],
      ),
      actions: const [],
    );
  }
}
