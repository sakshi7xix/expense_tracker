import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../app_model.dart';
import '../../core/tokens.dart';
import '../../data/remote.dart';
import '../../ui/kit/glass.dart';
import '../../ui/kit/kit.dart';
import '../account/sign_in_page.dart';

/// "K7Q2M9AB" → "K7Q2 M9AB", easier to read out.
String formatFriendCode(String code) => code.length == 8 ? '${code.substring(0, 4)} ${code.substring(4)}' : code;

/// Friends are added only with their personal friend code: type it, they get
/// a request, and they join your list when they accept. Always returns null,
/// because nobody is added until they accept.
Future<int?> showAddFriend(BuildContext context) async {
  await showGlassSheet<void>(context, (_) => AddFriendSheet());
  return null;
}

class AddFriendSheet extends StatefulWidget {
  const AddFriendSheet({super.key});

  @override
  State<AddFriendSheet> createState() => _AddFriendSheetState();
}

class _AddFriendSheetState extends State<AddFriendSheet> {
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;
  String? _sentTo;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final sync = StubScope.of(context).sync;
    final code = _code.text.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
    if (sync == null) return;
    if (code.length != 8) {
      setState(() => _error = 'A friend code has 8 letters and numbers');
      return;
    }
    if (code == sync.myCode) {
      setState(() => _error = 'That’s your own code');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final name = await sync.request(code);
      HapticFeedback.mediumImpact();
      if (mounted) setState(() => _sentTo = name);
    } on RemoteFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Couldn’t send it. Check your connection.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final model = StubScope.of(context);
    final sync = model.sync;
    const muted = TextStyle(fontSize: 13, height: 1.45, fontWeight: FontWeight.w700, color: StubColors.muted);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(22, 10, 22, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: const SheetGrab()),
              Text('Add a friend', textAlign: TextAlign.center, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: StubColors.ink)),
              SizedBox(height: 14),
              if (sync == null) ...[
                Text(
                  'Friends add each other with their Bilby friend code. Sign in to get yours.',
                  textAlign: TextAlign.center,
                  style: muted,
                ),
                SizedBox(height: 16),
                if (model.auth.available)
                  PillButton(
                    key: Key('add-friend-sign-in'),
                    label: 'Sign in',
                    onPressed: () async {
                      Navigator.of(context).pop();
                      await showSignIn(context);
                    },
                  ),
              ] else if (_sentTo != null) ...[
                Icon(Icons.mark_email_read_outlined, size: 40, color: StubColors.owed),
                SizedBox(height: 10),
                Text(
                  'Request sent to $_sentTo',
                  key: Key('request-sent'),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: StubColors.ink),
                ),
                SizedBox(height: 6),
                Text('They’ll appear in your friends once they accept.', textAlign: TextAlign.center, style: muted),
                SizedBox(height: 16),
                PillButton(label: 'Done', onPressed: () => Navigator.of(context).pop()),
              ] else ...[
                SoftCard(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Your friend code', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: StubColors.muted)),
                            SizedBox(height: 2),
                            Text(
                              sync.myCode == null ? '…' : formatFriendCode(sync.myCode!),
                              key: Key('my-code'),
                              style: TextStyle(fontFamily: 'IBMPlexMono', fontSize: 22, letterSpacing: 2, fontWeight: FontWeight.w500, color: StubColors.ink),
                            ),
                          ],
                        ),
                      ),
                      if (sync.myCode != null)
                        IconButton(
                          key: Key('copy-my-code'),
                          tooltip: 'Copy your code',
                          icon: Icon(Icons.copy_rounded, color: StubColors.muted),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: sync.myCode!));
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Your code is copied')));
                          },
                        ),
                    ],
                  ),
                ),
                SizedBox(height: 6),
                Text('Give this to friends so they can add you.', style: muted),
                SizedBox(height: 18),
                Text('Their code', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: StubColors.muted)),
                SizedBox(height: 6),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                  decoration: BoxDecoration(color: StubColors.page, borderRadius: BorderRadius.circular(16)),
                  child: TextField(
                    key: Key('friend-code-field'),
                    controller: _code,
                    autofocus: true,
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [LengthLimitingTextInputFormatter(12)],
                    onSubmitted: (_) => _send(),
                    onChanged: (_) {
                      if (_error != null) setState(() => _error = null);
                    },
                    style: TextStyle(fontFamily: 'IBMPlexMono', fontSize: 20, letterSpacing: 2, color: StubColors.ink),
                    decoration: InputDecoration(
                      hintText: 'K7Q2 M9AB',
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                  ),
                ),
                if (_error != null)
                  Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(_error!, key: Key('friend-code-error'), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: StubColors.owe)),
                  ),
                SizedBox(height: 14),
                PillButton(key: Key('friend-request'), label: 'Send request', busy: _busy, onPressed: _send),
                SizedBox(height: 10),
                Text('Not on Bilby yet? They need to install it and sign in to get their code.', textAlign: TextAlign.center, style: muted),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
