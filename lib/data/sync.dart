import 'package:flutter/foundation.dart';

import '../core/money.dart';
import 'remote.dart';
import 'store.dart';

/// Keeps this phone and the server in step for one signed-in account:
/// uploads your shared spends and payments, brings in your friends', links
/// friends when they accept your invite, and holds friend requests for the
/// bell. Also keeps a private backup of everything on the phone, which only
/// this account can read, and brings it back on a new or reinstalled phone.
class Sync extends ChangeNotifier {
  Sync({required this.store, required this.remote, required this.me, required this.onChanged});

  final StubStore store;
  final Remote remote;
  final String me;

  /// Called after something on this phone changed, so screens refresh.
  final VoidCallback onChanged;

  List<FriendRequest> requests = const [];

  /// Your personal friend code, once fetched.
  String? myCode;

  /// Requests you sent that haven't been accepted yet.
  List<SentInvite> waiting = const [];
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

    myCode ??= await remote.myCode();

    // A new or reinstalled phone: bring back the backup first, so what
    // follows matches up with it.
    if (!store.backupRestored) {
      final spends = store.restoreBackup(await remote.loadBackup());
      store.backupRestored = true;
      if (spends > 0) {
        store.addNotice(
          ref: 'restored:$me',
          title: 'Your spends are back',
          sub: '$spends ${spends == 1 ? 'spend' : 'spends'} restored from your backup',
          who: 'Bilby',
        );
        changed = true;
      }
    }

    // People who accepted your requests become friends on this phone.
    final names = <String, String>{};
    final sent = await remote.sentInvites();
    for (final inv in sent) {
      if (inv.status != 'accepted' || inv.acceptedBy == null) continue;
      final old = store.friendForInvite(inv.id);
      if (old != null) {
        store.linkFriend(old, inv.acceptedBy!);
      } else if (store.friendIdForUser(inv.acceptedBy!) == null) {
        _attach(inv.acceptedBy!, inv.toName);
      } else {
        continue;
      }
      final name = inv.toName.isEmpty ? 'Your friend' : inv.toName;
      store.addNotice(ref: 'accepted:${inv.id}', title: '$name accepted your request', sub: 'You can split with them now', who: name);
      changed = true;
    }
    waiting = [for (final inv in sent) if (inv.status != 'accepted' && inv.toUser != null) inv];

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

    await _backUp();
    requests = await remote.requests();
    if (changed) onChanged();
  }

  /// Uploads everything changed since the last backup, a batch at a time.
  Future<void> _backUp() async {
    var any = false;
    for (var batch = store.pendingBackup(); !batch.isEmpty; batch = store.pendingBackup()) {
      await remote.saveBackup(batch.rows);
      store.backedUp(batch);
      any = true;
    }
    if (any || store.backedUpAt == null) {
      store.markBackedUp();
      notifyListeners();
    }
  }

  /// A friend on this phone for an account: links a not-yet-linked friend of
  /// the same name (added before friend codes), else adds a new one.
  int _attach(String userId, String name) {
    final known = store.friendIdForUser(userId);
    if (known != null) return known;
    final sameName = store.friends().where((f) => f.name == name && store.userOfFriend(f.id) == null).firstOrNull;
    if (sameName != null) {
      store.linkFriend(sameName.id, userId);
      return sameName.id;
    }
    return store.friendForAccount(userId, name);
  }

  /// Sends a friend request to the owner of [code]. Returns their name.
  Future<String> request(String code) async {
    final r = await remote.requestFriend(code);
    if (r.accepted) {
      _attach(r.toUser, r.toName);
      onChanged();
    }
    await run();
    return r.toName;
  }

  /// Accept, decline or block ("I don't know them") a request.
  Future<void> answer(FriendRequest request, String answer) async {
    await remote.answer(request.id, request.code, answer);
    requests = [for (final r in requests) if (r.id != request.id) r];
    if (answer == 'accepted') {
      _attach(request.fromUser, request.fromName);
      onChanged();
    }
    notifyListeners();
    await run();
  }
}
