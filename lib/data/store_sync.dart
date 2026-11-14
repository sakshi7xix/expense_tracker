part of 'store.dart';

/// A spend of yours ready to upload: [shares] maps account id to share, with
/// your own share under the key `''` (the sync fills in your id).
class OutgoingExpense {
  const OutgoingExpense({
    required this.entryId,
    required this.remoteId,
    required this.title,
    required this.total,
    required this.day,
    required this.payer,
    required this.shares,
    required this.deleted,
  });

  final int entryId;
  final String remoteId;
  final String title;
  final int total;
  final String day;

  /// Payer's account id, or `''` for you.
  final String payer;
  final Map<String, int> shares;
  final bool deleted;
}

class OutgoingPayment {
  const OutgoingPayment({required this.ledgerId, required this.remoteId, required this.friendUser, required this.amount, required this.day});

  final int ledgerId;
  final String remoteId;
  final String friendUser;

  /// Positive: you paid them. Negative: they paid you.
  final int amount;
  final String day;
}

String newRemoteId() {
  final r = math.Random.secure();
  final b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
}

extension SyncStore on StubStore {
  /// The account this phone's data is linked to. Set on the first sync.
  String? get accountId => _setting('account_id');
  set accountId(String? id) => _setSetting('account_id', id ?? '');

  String? cursor(String key) {
    final v = _setting('cursor_$key');
    return v == null || v.isEmpty ? null : v;
  }

  void setCursor(String key, String value) => _setSetting('cursor_$key', value);

  int? friendIdForUser(String userId) {
    final rows = db.select('SELECT id FROM friend WHERE user_id = ?', [userId]);
    return rows.isEmpty ? null : rows.first['id'] as int;
  }

  String? userOfFriend(int friendId) {
    final rows = db.select('SELECT user_id FROM friend WHERE id = ?', [friendId]);
    return rows.isEmpty ? null : rows.first['user_id'] as String?;
  }

  void setInvite(int friendId, {required String id, required String code}) {
    db.execute('UPDATE friend SET invite_id = ?, invite_code = ? WHERE id = ?', [id, code, friendId]);
  }

  int? friendForInvite(String inviteId) {
    final rows = db.select('SELECT id FROM friend WHERE invite_id = ? AND user_id IS NULL', [inviteId]);
    return rows.isEmpty ? null : rows.first['id'] as int;
  }

  List<WaitingInvite> waitingInvites() {
    return [
      for (final r in db.select('SELECT id, name, invite_code FROM friend WHERE invite_code IS NOT NULL AND user_id IS NULL ORDER BY id'))
        WaitingInvite(friendId: r['id'] as int, name: r['name'] as String, code: r['invite_code'] as String),
    ];
  }

  /// Links a friend to their account and queues every split with them for
  /// upload, so what you shared before they joined shows on their phone too.
  void linkFriend(int friendId, String userId) {
    _tx(() {
      db.execute('UPDATE friend SET user_id = ? WHERE id = ?', [userId, friendId]);
      db.execute(
        'UPDATE entry SET dirty = 1 WHERE remote_by IS NULL AND id IN (SELECT entry_id FROM ledger WHERE friend_id = ? AND entry_id IS NOT NULL)',
        [friendId],
      );
      db.execute("UPDATE ledger SET dirty = 1 WHERE friend_id = ? AND kind = 'payment' AND remote_id IS NULL", [friendId]);
    });
  }

  /// A friend for an account: the one already linked, else a new one named
  /// [name] (made unique if you already have someone by that name).
  int friendForAccount(String userId, String name) {
    final known = friendIdForUser(userId);
    if (known != null) return known;
    var candidate = name.trim().isEmpty ? 'Friend' : name.trim();
    for (var n = 2; db.select('SELECT 1 FROM friend WHERE name = ?', [candidate]).isNotEmpty; n++) {
      candidate = '${name.trim()} $n';
    }
    return _insert('INSERT INTO friend (name, contact, user_id) VALUES (?, ?, ?)', [candidate, '', userId]);
  }

  /// Your spends waiting to go online. A split stays local until everyone in
  /// it has joined; then it uploads.
  List<OutgoingExpense> outgoingExpenses() {
    final out = <OutgoingExpense>[];
    for (final e in db.select('SELECT * FROM entry WHERE dirty = 1 AND remote_by IS NULL')) {
      final entryId = e['id'] as int;
      final lines = db.select(
        "SELECT l.friend_id, l.amount, f.user_id FROM ledger l JOIN friend f ON f.id = l.friend_id WHERE l.entry_id = ? AND l.kind = 'split'",
        [entryId],
      );
      final saved = {
        for (final r in db.select('SELECT friend_id, share FROM entry_share WHERE entry_id = ?', [entryId]))
          r['friend_id'] as int: r['share'] as int,
      };
      final users = {for (final r in db.select('SELECT id, user_id FROM friend')) r['id'] as int: r['user_id'] as String?};
      final total = e['total'] as int;
      final mine = e['amount'] as int;
      final payerLine = lines.where((r) => (r['amount'] as int) < 0).firstOrNull;
      final shares = <int, int>{...saved};
      if (shares.isEmpty) {
        if (payerLine == null) {
          for (final r in lines) {
            shares[r['friend_id'] as int] = r['amount'] as int;
          }
        } else if (lines.length == 1) {
          shares[payerLine['friend_id'] as int] = total - mine;
        }
      }
      final remoteId = e['remote_id'] as String?;
      final deleted = (e['deleted'] as int) == 1;
      final ready = shares.isNotEmpty && shares.keys.every((f) => users[f] != null) && shares.values.fold<int>(mine, (a, b) => a + b) == total;
      if (!ready) {
        // Not shareable yet. Nothing online to update, so stop asking.
        if (remoteId == null && shares.isEmpty) db.execute('UPDATE entry SET dirty = 0 WHERE id = ?', [entryId]);
        continue;
      }
      if (deleted && remoteId == null) {
        db.execute('UPDATE entry SET dirty = 0 WHERE id = ?', [entryId]);
        continue;
      }
      out.add(OutgoingExpense(
        entryId: entryId,
        remoteId: remoteId ?? newRemoteId(),
        title: e['title'] as String,
        total: total,
        day: e['day'] as String,
        payer: payerLine == null ? '' : users[payerLine['friend_id'] as int]!,
        shares: {'': mine, for (final s in shares.entries) users[s.key]!: s.value},
        deleted: deleted,
      ));
    }
    return out;
  }

  void expenseUploaded(int entryId, String remoteId) {
    db.execute('UPDATE entry SET remote_id = ?, dirty = 0 WHERE id = ?', [remoteId, entryId]);
  }

  List<OutgoingPayment> outgoingPayments() {
    return [
      for (final r in db.select(
        "SELECT l.id, l.amount, l.day, f.user_id FROM ledger l JOIN friend f ON f.id = l.friend_id "
        "WHERE l.kind = 'payment' AND l.dirty = 1 AND l.remote_id IS NULL AND l.deleted = 0 AND f.user_id IS NOT NULL",
      ))
        OutgoingPayment(
          ledgerId: r['id'] as int,
          remoteId: newRemoteId(),
          friendUser: r['user_id'] as String,
          amount: r['amount'] as int,
          day: r['day'] as String,
        ),
    ];
  }

  void paymentUploaded(int ledgerId, String remoteId) {
    db.execute('UPDATE ledger SET remote_id = ?, dirty = 0 WHERE id = ?', [remoteId, ledgerId]);
  }

  /// Applies a friend's shared expense to this phone. Returns true if it was new.
  bool applyExpense(RemoteExpense x, {required String me, required Map<String, String> names}) {
    final myShare = x.shares[me];
    if (x.createdBy == me || myShare == null) return false;
    return _tx(() {
      final existing = db.select('SELECT id FROM entry WHERE remote_id = ?', [x.id]);
      final other = categories().firstWhere((c) => c.name == 'Other', orElse: () => categories().last).id;
      late final int entryId;
      if (existing.isEmpty) {
        entryId = _insert(
          'INSERT INTO entry (title, amount, total, category_id, day, created_at, remote_id, remote_by, deleted) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
          [x.title, myShare, x.total, other, x.day, _now, x.id, x.createdBy, x.deleted ? 1 : 0],
        );
      } else {
        entryId = existing.first['id'] as int;
        db.execute(
          'UPDATE entry SET title = ?, amount = ?, total = ?, day = ?, deleted = ?, dirty = 0 WHERE id = ?',
          [x.title, myShare, x.total, x.day, x.deleted ? 1 : 0, entryId],
        );
        db.execute('DELETE FROM ledger WHERE entry_id = ?', [entryId]);
      }
      void line(String userId, int amount) {
        if (amount == 0) return;
        final friendId = friendForAccount(userId, names[userId] ?? 'Deleted user');
        db.execute(
          "INSERT INTO ledger (friend_id, entry_id, title, amount, kind, day, created_at, deleted) VALUES (?, ?, ?, ?, 'split', ?, ?, ?)",
          [friendId, entryId, x.title, amount, x.day, _now, x.deleted ? 1 : 0],
        );
      }

      if (x.payer == me) {
        x.shares.forEach((user, share) {
          if (user != me) line(user, share);
        });
      } else {
        line(x.payer, -myShare);
      }
      return existing.isEmpty && !x.deleted;
    });
  }

  /// Applies a payment a friend recorded. Returns true if it was new.
  bool applyPayment(RemotePayment p, {required String me, required Map<String, String> names}) {
    if (p.createdBy == me || (p.from != me && p.to != me)) return false;
    final existing = db.select('SELECT id FROM ledger WHERE remote_id = ?', [p.id]);
    if (existing.isNotEmpty) {
      db.execute('UPDATE ledger SET deleted = ? WHERE id = ?', [p.deleted ? 1 : 0, existing.first['id']]);
      return false;
    }
    final other = p.from == me ? p.to : p.from;
    final friendId = friendForAccount(other, names[other] ?? 'Deleted user');
    final name = names[other] ?? 'Friend';
    db.execute(
      "INSERT INTO ledger (friend_id, title, amount, kind, day, created_at, remote_id, deleted) VALUES (?, ?, ?, 'payment', ?, ?, ?, ?)",
      [friendId, p.from == me ? 'You paid $name' : '$name paid you', p.from == me ? p.amount : -p.amount, p.day, _now, p.id, p.deleted ? 1 : 0],
    );
    return !p.deleted;
  }

  void addNotice({required String ref, required String title, required String sub, required String who}) {
    db.execute('INSERT OR IGNORE INTO notice (ref, title, sub, who, at) VALUES (?, ?, ?, ?, ?)', [ref, title, sub, who, _now]);
  }

  List<Notice> notices({int limit = 40}) {
    return [
      for (final r in db.select('SELECT * FROM notice ORDER BY at DESC, id DESC LIMIT ?', [limit]))
        Notice(
          id: r['id'] as int,
          title: r['title'] as String,
          sub: r['sub'] as String,
          who: r['who'] as String,
          at: r['at'] as int,
          seen: (r['seen'] as int) == 1,
        ),
    ];
  }

  int get unseenNotices => db.select('SELECT COUNT(*) AS n FROM notice WHERE seen = 0').first['n'] as int;

  void markNoticesSeen() => db.execute('UPDATE notice SET seen = 1 WHERE seen = 0');
}
