import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';

import '../../app_model.dart';
import '../../data/remote.dart';
import '../../data/store.dart';
import '../account/sign_in_page.dart';

/// The message shared with a friend you invite.
String inviteMessage(String name, String code) =>
    'Hi $name! I’m keeping our shared expenses on Bilby. Get the app, sign in, tap the bell and enter my '
    'invite code $code so we both see the same splits.';

void _say(ScaffoldMessengerState messenger, String text) {
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}

/// Invites a friend who is on this phone: signs in first if needed, creates
/// the invite online and opens the share sheet with its code.
Future<void> inviteFriend(BuildContext context, int friendId) async {
  final model = StubScope.of(context);
  final messenger = ScaffoldMessenger.of(context);
  if (model.sync == null) {
    if (!model.auth.available) return _say(messenger, 'Inviting needs the internet. Try again later.');
    final ok = await showSignIn(context);
    if (ok != true || model.sync == null) return;
  }
  final name = model.store.friends().firstWhere((f) => f.id == friendId).name;
  try {
    final code = await model.sync!.invite(friendId);
    await shareInvite(name, code);
  } on RemoteFailure catch (e) {
    _say(messenger, e.message);
  } catch (_) {
    _say(messenger, 'Couldn’t create the invite. Check your connection.');
  }
}

Future<void> shareInvite(String name, String code) async {
  await SharePlus.instance.share(ShareParams(text: inviteMessage(name, code), subject: 'Split expenses with me'));
}
