part of 'store.dart';

extension Friends on StubStore {
  /// Adds a friend and returns their id. Names are unique, ignoring case.
  int addFriend(String name, {String contact = ''}) {
    final clean = name.trim();
    if (clean.isEmpty) throw ArgumentError('A friend needs a name');
    final existing = db.select('SELECT id FROM friend WHERE name = ?', [clean]);
    if (existing.isNotEmpty) throw StateError('$clean is already a friend');
    return _insert('INSERT INTO friend (name, contact) VALUES (?, ?)', [clean, contact.trim()]);
  }

  void setFriendContact(int friendId, String contact) {
    db.execute('UPDATE friend SET contact = ? WHERE id = ?', [contact.trim(), friendId]);
  }

  /// Every friend with their balance. Positive: they owe you.
  List<FriendBalance> friends() {
    final rows = db.select(
      'SELECT f.id, f.name, f.contact, f.joined, COALESCE(SUM(l.amount), 0) AS balance '
      'FROM friend f LEFT JOIN ledger l ON l.friend_id = f.id AND l.deleted = 0 '
      'GROUP BY f.id ORDER BY f.id',
    );
    return [
      for (final row in rows)
        FriendBalance(
          id: row['id'] as int,
          name: row['name'] as String,
          contact: row['contact'] as String,
          joined: (row['joined'] as int) == 1,
          balance: row['balance'] as int,
        ),
    ];
  }

  int balanceOf(int friendId) {
    final rows = db.select(
      'SELECT COALESCE(SUM(amount), 0) AS b FROM ledger WHERE friend_id = ? AND deleted = 0',
      [friendId],
    );
    return rows.first['b'] as int;
  }

  /// Total others owe you, in paise.
  int get owedToYou => friends().fold(0, (sum, f) => sum + math.max(0, f.balance));

  /// Total you owe others, in paise.
  int get youOwe => friends().fold(0, (sum, f) => sum + math.max(0, -f.balance));

  /// Records a payment that reduces the balance with a friend, in whichever
  /// direction it runs. Never pays more than is open. Returns paise recorded.
  int settle(int friendId, int paise, {required DateTime day}) {
    final balance = balanceOf(friendId);
    if (balance == 0 || paise <= 0) return 0;
    final amount = math.min(paise, balance.abs());
    final name = db.select('SELECT name FROM friend WHERE id = ?', [friendId]).first['name'] as String;
    final theyPaid = balance > 0;
    db.execute(
      'INSERT INTO ledger (friend_id, title, amount, kind, day, created_at) '
      "VALUES (?, ?, ?, 'payment', ?, ?)",
      [friendId, theyPaid ? '$name paid you' : 'You paid $name', theyPaid ? -amount : amount, dayKey(day), _now],
    );
    return amount;
  }

  LedgerItem _ledgerItem(Row row) {
    return LedgerItem(
      id: row['id'] as int,
      friendId: row['friend_id'] as int,
      friendName: row['name'] as String,
      title: row['title'] as String,
      amount: row['amount'] as int,
      isPayment: row['kind'] == 'payment',
      day: row['day'] as String,
    );
  }

  /// Shared history, newest first, for one friend or for everyone.
  List<LedgerItem> activity({int? friendId, int limit = 50}) {
    final rows = db.select(
      'SELECT l.*, f.name FROM ledger l JOIN friend f ON f.id = l.friend_id '
      'WHERE l.deleted = 0 AND (? IS NULL OR l.friend_id = ?) '
      'ORDER BY l.day DESC, l.created_at DESC, l.id DESC LIMIT ?',
      [friendId, friendId, limit],
    );
    return rows.map(_ledgerItem).toList();
  }

  int addGroup(String name, List<int> memberIds) {
    final clean = name.trim();
    if (clean.isEmpty || memberIds.isEmpty) {
      throw ArgumentError('A group needs a name and at least one friend');
    }
    return _tx(() {
      final id = _insert('INSERT INTO grp (name) VALUES (?)', [clean]);
      for (final friendId in memberIds.toSet()) {
        db.execute('INSERT INTO grp_member (grp_id, friend_id) VALUES (?, ?)', [id, friendId]);
      }
      return id;
    });
  }

  List<Group> groups() {
    return [
      for (final row in db.select('SELECT id, name FROM grp ORDER BY id'))
        Group(
          id: row['id'] as int,
          name: row['name'] as String,
          memberIds: [
            for (final m in db.select(
              'SELECT friend_id FROM grp_member WHERE grp_id = ? ORDER BY friend_id',
              [row['id']],
            ))
              m['friend_id'] as int,
          ],
        ),
    ];
  }
}
