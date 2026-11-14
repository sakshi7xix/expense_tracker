import 'package:stub/data/remote.dart';

/// An in-memory stand-in for the server, enforcing the same rules as the
/// database functions: friends only, shares add up, creator-only changes.
class FakeServer {
  final emails = <String, String>{};
  final names = <String, String>{};
  final codes = <String, String>{};
  final invites = <String, Map<String, String?>>{};
  final friendships = <String>{};
  final expenses = <String, RemoteExpense>{};
  final payments = <String, RemotePayment>{};

  /// Account id to its private backup, keyed by 'kind/key'.
  final backups = <String, Map<String, BackupRow>>{};
  int _clock = 0;
  int _ids = 0;

  String tick() => (++_clock).toString().padLeft(8, '0');
  String newId() => 'id-${++_ids}';

  void addUser(String id, String email, String name, {String? code}) {
    emails[id] = email;
    names[id] = name;
    codes[id] = code ?? 'CODE${id.padRight(4, 'X')}'.substring(0, 8).toUpperCase();
  }

  bool friends(String a, String b) => friendships.contains(([a, b]..sort()).join('|'));
}

class FakeRemote implements Remote {
  FakeRemote(this.server, this.me);

  final FakeServer server;
  final String me;

  @override
  Future<String> myCode() async => server.codes[me]!;

  @override
  Future<({String toUser, String toName, bool accepted})> requestFriend(String code) async {
    final clean = code.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
    final target = server.codes.entries.where((e) => e.value == clean).firstOrNull?.key;
    if (target == null) throw const RemoteFailure('No one has that code. Check it with your friend.');
    if (target == me) throw const RemoteFailure('That’s your own code.');
    if (server.friends(me, target)) throw const RemoteFailure('You’re already friends.');
    final theirs = server.invites.entries.where((e) => e.value['from'] == target && e.value['to'] == me && e.value['status'] == 'pending').firstOrNull;
    if (theirs != null) {
      theirs.value['status'] = 'accepted';
      theirs.value['by'] = me;
      server.friendships.add(([me, target]..sort()).join('|'));
      return (toUser: target, toName: server.names[target]!, accepted: true);
    }
    final blocked = server.invites.values.any((i) => i['from'] == me && i['to'] == target && i['status'] == 'blocked');
    server.invites[server.newId()] = {'from': me, 'to': target, 'name': server.names[target], 'status': blocked ? 'blocked' : 'pending', 'by': null};
    return (toUser: target, toName: server.names[target]!, accepted: false);
  }

  @override
  Future<List<SentInvite>> sentInvites() async => [
        for (final e in server.invites.entries)
          if (e.value['from'] == me)
            SentInvite(id: e.key, status: e.value['status']!, acceptedBy: e.value['by'], toUser: e.value['to'], toName: e.value['name'] ?? ''),
      ];

  String _masked(String email) => '${email.substring(0, 3)}•••@${email.split('@').last}';

  @override
  Future<List<FriendRequest>> requests() async => [
        for (final e in server.invites.entries)
          if (e.value['status'] == 'pending' && e.value['to'] == me)
            FriendRequest(
              id: e.key,
              fromUser: e.value['from']!,
              fromName: server.names[e.value['from']]!,
              fromEmail: _masked(server.emails[e.value['from']]!),
            ),
      ];

  @override
  Future<String> answer(String inviteId, String? code, String answer) async {
    final i = server.invites[inviteId];
    if (i == null || i['status'] != 'pending' || i['to'] != me) {
      throw const RemoteFailure('That invite has expired or was already used.');
    }
    i['status'] = answer;
    if (answer == 'accepted') {
      i['by'] = me;
      server.friendships.add(([me, i['from']!]..sort()).join('|'));
    }
    return i['from']!;
  }

  @override
  Future<Map<String, String>> names(Iterable<String> userIds) async => {
        for (final id in userIds)
          if (server.names.containsKey(id)) id: server.names[id]!,
      };

  @override
  Future<void> saveExpense({
    required String id,
    required String title,
    required int total,
    required String payer,
    required String day,
    required Map<String, int> shares,
  }) async {
    final old = server.expenses[id];
    if (old != null && old.createdBy != me) throw const RemoteFailure('only the person who added it can change it');
    for (final u in shares.keys) {
      if (u != me && !server.friends(me, u)) throw const RemoteFailure('not your friend');
    }
    if (!shares.containsKey(me) || !shares.containsKey(payer) || shares.values.fold<int>(0, (a, b) => a + b) != total) {
      throw const RemoteFailure('shares must add up to the total');
    }
    server.expenses[id] = RemoteExpense(
      id: id, createdBy: me, title: title, total: total, payer: payer, day: day, deleted: false, shares: shares, updatedAt: server.tick());
  }

  @override
  Future<void> deleteExpense(String id, {bool deleted = true}) async {
    final x = server.expenses[id];
    if (x == null || x.createdBy != me) throw const RemoteFailure('only the person who added it can delete it');
    server.expenses[id] = RemoteExpense(
      id: id, createdBy: me, title: x.title, total: x.total, payer: x.payer, day: x.day, deleted: deleted, shares: x.shares, updatedAt: server.tick());
  }

  @override
  Future<void> savePayment({required String id, required String from, required String to, required int amount, required String day}) async {
    final other = from == me ? to : from;
    if ((from != me && to != me) || !server.friends(me, other)) throw const RemoteFailure('not your friend');
    server.payments[id] ??= RemotePayment(
      id: id, from: from, to: to, amount: amount, day: day, createdBy: me, deleted: false, updatedAt: server.tick());
  }

  @override
  Future<List<RemoteExpense>> expensesSince(String? since) async => [
        for (final x in server.expenses.values)
          if (x.shares.containsKey(me) && (since == null || x.updatedAt.compareTo(since) > 0)) x,
      ]..sort((a, b) => a.updatedAt.compareTo(b.updatedAt));

  @override
  Future<List<RemotePayment>> paymentsSince(String? since) async => [
        for (final p in server.payments.values)
          if ((p.from == me || p.to == me) && (since == null || p.updatedAt.compareTo(since) > 0)) p,
      ]..sort((a, b) => a.updatedAt.compareTo(b.updatedAt));

  @override
  Future<void> saveBackup(List<BackupRow> rows) async {
    final mine = server.backups.putIfAbsent(me, () => {});
    for (final r in rows) {
      mine['${r.kind}/${r.key}'] = r;
    }
  }

  @override
  Future<List<BackupRow>> loadBackup() async => [...?server.backups[me]?.values];
}
