import 'package:flutter/foundation.dart';

import '../core/money.dart';
import 'remote.dart';
import 'store.dart';

/// Keeps this phone and the server in step for one signed-in account:
/// uploads your shared spends and payments, brings in your friends', links
/// friends when they accept your invite, and holds friend requests for the
/// bell. Personal spends never leave the phone.
class Sync extends ChangeNotifier {
  Sync({required this.store, required this.remote, required this.me, required this.onChanged});

  final StubStore store;
  final Remote remote;
  final String me;

  /// Called after something on this phone changed, so screens refresh.
  final VoidCallback onChanged;

  List<FriendRequest> requests = const [];
  bool running = false;
  String? problem;
  bool _again = false;

  /// This phone's data belongs to another account: don't mix them.
  bool get blocked => store.accountId != null && store.accountId!.isNotEmpty && store.accountId != me;

  /// Runs a full sync. Calls made while one is running queue one more pass.
  Future<void> run() async {
    if (blocked) return;
    if (running) {
      _again = true;
      return;
    }
    running = true;
    notifyListeners();
    try {
      do {
        _again = false;
        await _pass();
      } while (_again);
      problem = null;
    } on RemoteFailure catch (e) {
      problem = e.message;
    } catch (e) {
      problem = 'Couldn’t sync. Check your connection.';
      debugPrint('sync failed: $e');
    } finally {
      running = false;
      notifyListeners();
    }
  }

  Future<void> _pass() async {
    if (store.accountId == null || store.accountId!.isEmpty) store.accountId = me;
    var changed = false;

    // Friends who accepted your invites.
    final names = <String, String>{};
    for (final inv in await remote.sentInvites()) {
      if (inv.status != 'accepted' || inv.acceptedBy == null) continue;
      final friendId = store.friendForInvite(inv.id);
      if (friendId == null) continue;
      store.linkFriend(friendId, inv.acceptedBy!);
      final name = store.friends().firstWhere((f) => f.id == friendId).name;
      store.addNotice(ref: 'accepted:${inv.id}', title: '$name accepted your invite', sub: 'Your splits show on their phone too', who: name);
      changed = true;
    }

    // Upload.
    for (final x in store.outgoingExpenses()) {
      if (x.deleted) {
        await remote.deleteExpense(x.remoteId);
      } else {
        await remote.saveExpense(
          id: x.remoteId,
          title: x.title,
          total: x.total,
          payer: x.payer.isEmpty ? me : x.payer,
          day: x.day,
          shares: {for (final s in x.shares.entries) s.key.isEmpty ? me : s.key: s.value},
        );
      }
      store.expenseUploaded(x.entryId, x.remoteId);
    }
    for (final p in store.outgoingPayments()) {
      await remote.savePayment(
        id: p.remoteId,
        from: p.amount > 0 ? me : p.friendUser,
        to: p.amount > 0 ? p.friendUser : me,
        amount: p.amount.abs(),
        day: p.day,
      );
      store.paymentUploaded(p.ledgerId, p.remoteId);
    }

    // Download.
    final expenses = await remote.expensesSince(store.cursor('expenses'));
    final payments = await remote.paymentsSince(store.cursor('payments'));
    final people = {
      for (final x in expenses) ...[x.createdBy, x.payer, ...x.shares.keys],
      for (final p in payments) ...[p.from, p.to],
    }..remove(me);
    if (people.isNotEmpty) names.addAll(await remote.names(people));

    for (final x in expenses) {
      if (store.applyExpense(x, me: me, names: names)) {
        final who = names[x.createdBy] ?? 'A friend';
        final mine = x.shares[me] ?? 0;
        store.addNotice(
          ref: 'expense:${x.id}',
          title: '$who added “${x.title}”',
          sub: x.payer == me ? 'Your share ${formatInr(mine)}' : 'You owe ${formatInr(mine)}',
          who: who,
        );
      }
      changed = true;
      store.setCursor('expenses', x.updatedAt);
    }
    for (final p in payments) {
      if (store.applyPayment(p, me: me, names: names)) {
        final who = names[p.from == me ? p.to : p.from] ?? 'A friend';
        store.addNotice(
          ref: 'payment:${p.id}',
          title: p.from == me ? '$who marked your payment of ${formatInr(p.amount)}' : '$who paid you ${formatInr(p.amount)}',
          sub: 'Settled up',
          who: who,
        );
      }
      changed = true;
      store.setCursor('payments', p.updatedAt);
    }

    requests = await remote.requests();
    if (changed) onChanged();
  }

  /// Creates an invite for a friend on this phone. Returns the code to share.
  Future<String> invite(int friendId) async {
    final friend = store.friends().firstWhere((f) => f.id == friendId);
    final made = await remote.createInvite(friend.name, friend.contact.contains('@') ? friend.contact : null);
    store.setInvite(friendId, id: made.id, code: made.code);
    onChanged();
    return made.code;
  }

  Future<FriendRequest?> findCode(String code) => remote.inviteByCode(code);

  /// Accept, decline or block ("I don't know them") a request.
  Future<void> answer(FriendRequest request, String answer) async {
    await remote.answer(request.id, request.code, answer);
    requests = [for (final r in requests) if (r.id != request.id) r];
    if (answer == 'accepted') {
      final existing = store.friends().where((f) => f.name == request.fromName && store.userOfFriend(f.id) == null).firstOrNull;
      if (existing != null) {
        store.linkFriend(existing.id, request.fromUser);
      } else {
        store.friendForAccount(request.fromUser, request.fromName);
      }
      onChanged();
    }
    notifyListeners();
    await run();
  }
}
