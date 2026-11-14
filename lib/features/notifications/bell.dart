import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../app_model.dart';
import '../../core/tokens.dart';
import '../../data/models.dart';
import '../../data/remote.dart';
import '../../data/store.dart';
import '../../ui/kit/glass.dart';
import '../../ui/kit/kit.dart';
import '../../ui/kit/motion.dart';
import '../account/sign_in_art.dart';
import '../account/sign_in_page.dart';
import '../friends/invite.dart';

/// Requests waiting plus updates you haven't seen.
int bellCount(AppModel model) => (model.sync?.requests.length ?? 0) + model.store.unseenNotices;

/// The bell at the top of Home and Friends. Shows a bouncing count and rings
/// every few seconds while something is waiting.
class BellButton extends StatelessWidget {
  const BellButton({super.key});

  @override
  Widget build(BuildContext context) {
    final model = StubScope.of(context);
    final count = bellCount(model);
    return Semantics(
      button: true,
      label: count == 0 ? 'Notifications' : 'Notifications, $count new',
      child: Pressable(
        key: Key('bell'),
        scale: 0.88,
        onTap: () => showNotices(context),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: StubColors.surface,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Color(0x141E1E28), blurRadius: 12, offset: Offset(0, 4))],
                ),
                child: LoopBuilder(
                  period: Duration(milliseconds: 2400),
                  builder: (context, t) {
                    // A short ring near the end of each loop, only while something waits.
                    final k = t < 0.62 ? 0.0 : (t - 0.62) / 0.38;
                    return Transform.rotate(
                      angle: count == 0 ? 0 : 0.35 * math.sin(k * math.pi * 6) * (1 - k),
                      alignment: Alignment(0, -0.6),
                      child: Icon(Icons.notifications_none_rounded, size: 21, color: StubColors.ink),
                    );
                  },
                ),
              ),
              if (count > 0)
                Positioned(
                  top: -3,
                  right: -2,
                  child: TweenAnimationBuilder<double>(
                    key: ValueKey(count),
                    tween: Tween(begin: 0.4, end: 1),
                    duration: Duration(milliseconds: 500),
                    curve: Curves.elasticOut,
                    builder: (context, s, child) => Transform.scale(scale: s, child: child),
                    child: Container(
                      key: Key('bell-count'),
                      constraints: BoxConstraints(minWidth: 18),
                      height: 18,
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: StubColors.pop,
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: StubColors.page, width: 2),
                      ),
                      child: Text('$count', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> showNotices(BuildContext context) async {
  final model = StubScope.of(context);
  model.sync?.run();
  await showGlassSheet<void>(context, (_) => NoticesSheet());
  model.write((s) => s.markNoticesSeen());
}

/// Requests, an invite-code box, new updates, invites still waiting, and
/// earlier updates.
class NoticesSheet extends StatefulWidget {
  const NoticesSheet({super.key});

  @override
  State<NoticesSheet> createState() => _NoticesSheetState();
}

class _NoticesSheetState extends State<NoticesSheet> {
  final _code = TextEditingController();
  FriendRequest? _found;
  String? _codeError;
  bool _busy = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _lookUp() async {
    final sync = StubScope.of(context).sync;
    if (sync == null || _code.text.trim().length < 6) return;
    setState(() {
      _busy = true;
      _codeError = null;
    });
    try {
      final r = await sync.findCode(_code.text.trim());
      setState(() {
        _found = r;
        _codeError = r == null ? 'No invite with that code. Check it with your friend.' : null;
      });
    } on RemoteFailure catch (e) {
      setState(() => _codeError = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _answer(FriendRequest r, String answer) async {
    final sync = StubScope.of(context).sync!;
    final messenger = ScaffoldMessenger.of(context);
    if (answer == 'accepted') HapticFeedback.mediumImpact();
    try {
      await sync.answer(r, answer);
      if (_found?.id == r.id) setState(() => _found = null);
      if (answer == 'accepted') {
        messenger.showSnackBar(SnackBar(content: Text('You and ${r.fromName} are friends now')));
      }
    } on RemoteFailure catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final model = StubScope.of(context);
    final sync = model.sync;
    final notices = model.store.notices();
    final fresh = [for (final n in notices) if (!n.seen) n];
    final earlier = [for (final n in notices) if (n.seen) n];
    final waiting = model.store.waitingInvites();
    final requests = [...?sync?.requests, if (_found != null && !(sync?.requests.any((r) => r.id == _found!.id) ?? false)) _found!];

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.86),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16, 10, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: const SheetGrab()),
              Center(child: Text('Notifications', style: Theme.of(context).textTheme.titleMedium)),
              if (sync == null) ...[
                SizedBox(height: 18),
                Text(
                  'Sign in to get friend requests and see splits your friends add.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: StubColors.muted),
                ),
                SizedBox(height: 14),
                if (model.auth.available)
                  PillButton(
                    key: Key('bell-sign-in'),
                    label: 'Sign in',
                    onPressed: () {
                      Navigator.of(context).pop();
                      showSignIn(context);
                    },
                  ),
              ] else ...[
                if (requests.isNotEmpty) _Head('Requests'),
                for (final r in requests) _RequestCard(request: r, onAnswer: (a) => _answer(r, a)),
                _Head('Have an invite code?'),
                SoftCard(
                  padding: EdgeInsets.fromLTRB(14, 4, 6, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          key: Key('invite-code'),
                          controller: _code,
                          textCapitalization: TextCapitalization.characters,
                          onSubmitted: (_) => _lookUp(),
                          style: TextStyle(fontFamily: 'IBMPlexMono', fontSize: 16, letterSpacing: 2, color: StubColors.ink),
                          decoration: InputDecoration(
                            hintText: 'K7Q2M9AB3F',
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                          ),
                        ),
                      ),
                      _busy
                          ? Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)))
                          : TextButton(key: Key('invite-code-find'), onPressed: _lookUp, child: Text('Find')),
                    ],
                  ),
                ),
                if (_codeError != null)
                  Padding(
                    padding: EdgeInsets.only(top: 6, left: 4),
                    child: Text(_codeError!, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: StubColors.owe)),
                  ),
                if (fresh.isNotEmpty) _Head('New'),
                for (final n in fresh) _NoticeRow(notice: n),
                if (waiting.isNotEmpty) _Head('Waiting to join'),
                for (final w in waiting) _WaitingRow(invite: w),
                if (earlier.isNotEmpty) _Head('Earlier'),
                for (final n in earlier) Opacity(opacity: 0.65, child: _NoticeRow(notice: n)),
                if (requests.isEmpty && notices.isEmpty && waiting.isEmpty)
                  Padding(
                    padding: EdgeInsets.only(top: 18),
                    child: Text('All caught up', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w800, color: StubColors.muted)),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Head extends StatelessWidget {
  const _Head(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(4, 16, 4, 8),
        child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: StubColors.muted)),
      );
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.request, required this.onAnswer});

  final FriendRequest request;
  final ValueChanged<String> onAnswer;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: SoftCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Avatar(name: request.fromName, radius: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${request.fromName} wants to add you', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: StubColors.ink)),
                      if (request.fromEmail.isNotEmpty)
                        Text(request.fromEmail, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: StubColors.muted)),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: PillButton(key: Key('accept-${request.id}'), label: 'Accept', onPressed: () => onAnswer('accepted'))),
                SizedBox(width: 8),
                Expanded(child: FrostButton(key: Key('decline-${request.id}'), label: 'Not now', height: 54, onPressed: () => onAnswer('declined'))),
              ],
            ),
            TextButton(
              key: Key('block-${request.id}'),
              onPressed: () => onAnswer('blocked'),
              style: TextButton.styleFrom(foregroundColor: StubColors.muted),
              child: Text('I don’t know them', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoticeRow extends StatelessWidget {
  const _NoticeRow({required this.notice});

  final Notice notice;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 6),
      child: SoftCard(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        child: Row(
          children: [
            if (!notice.seen)
              Container(width: 8, height: 8, margin: EdgeInsets.only(right: 8), decoration: BoxDecoration(color: StubColors.pop, shape: BoxShape.circle)),
            Avatar(name: notice.who, radius: 16),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(notice.title, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: StubColors.ink)),
                  Text(notice.sub, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: StubColors.muted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WaitingRow extends StatelessWidget {
  const _WaitingRow({required this.invite});

  final WaitingInvite invite;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 6),
      child: SoftCard(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Avatar(name: invite.name, radius: 16),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${invite.name} hasn’t joined yet', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: StubColors.ink)),
                  Text('Code ${invite.code}', style: TextStyle(fontFamily: 'IBMPlexMono', fontSize: 11.5, color: StubColors.muted)),
                ],
              ),
            ),
            SizedBox(
              width: 92,
              child: FrostButton(
                key: Key('resend-${invite.friendId}'),
                label: 'Send again',
                height: 38,
                onPressed: () => shareInvite(invite.name, invite.code),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
