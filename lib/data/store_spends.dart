part of 'store.dart';

extension Spends on StubStore {
  /// Saves a spend of [total] paise.
  ///
  /// [friendShares] maps friend id to that friend's share. Your own share is
  /// whatever is left, and only that counts against the budget. If
  /// [payerFriendId] is set, that friend paid the bill, so you owe them your
  /// share; otherwise you paid and each friend owes you theirs.
  int addSpend({
    required String title,
    required int total,
    required int categoryId,
    required DateTime day,
    Map<int, int> friendShares = const {},
    int? payerFriendId,
    int? billId,
  }) {
    final others = friendShares.values.fold<int>(0, (a, b) => a + b);
    final mine = total - others;
    if (total <= 0 || mine < 0) {
      throw ArgumentError('Shares do not fit the total');
    }
    if (payerFriendId != null && !friendShares.containsKey(payerFriendId)) {
      throw ArgumentError('The payer must be part of the split');
    }
    return _tx(() {
      final entryId = _insert(
        'INSERT INTO entry (title, amount, total, category_id, day, created_at, bill_id) '
        'VALUES (?, ?, ?, ?, ?, ?, ?)',
        [title, mine, total, categoryId, dayKey(day), _now, billId],
      );
      void lend(int friendId, int amount) {
        if (amount == 0) return;
        db.execute(
          'INSERT INTO ledger (friend_id, entry_id, title, amount, kind, day, created_at) '
          "VALUES (?, ?, ?, ?, 'split', ?, ?)",
          [friendId, entryId, title, amount, dayKey(day), _now],
        );
      }

      if (payerFriendId == null) {
        friendShares.forEach(lend);
      } else {
        lend(payerFriendId, -mine);
      }
      return entryId;
    });
  }

  /// Soft-deletes a spend and its split lines; [restoreSpend] undoes it.
  void deleteSpend(int entryId) => _setDeleted(entryId, 1);

  void restoreSpend(int entryId) => _setDeleted(entryId, 0);

  void _setDeleted(int entryId, int flag) {
    _tx(() {
      db.execute('UPDATE entry SET deleted = ? WHERE id = ?', [flag, entryId]);
      db.execute('UPDATE ledger SET deleted = ? WHERE entry_id = ?', [flag, entryId]);
    });
  }

  void renameSpend(int entryId, {required String title, required int categoryId}) {
    db.execute(
      'UPDATE entry SET title = ?, category_id = ? WHERE id = ?',
      [title, categoryId, entryId],
    );
  }

  Entry _entry(Row row) {
    return Entry(
      id: row['id'] as int,
      title: row['title'] as String,
      amount: row['amount'] as int,
      total: row['total'] as int,
      categoryId: row['category_id'] as int,
      day: row['day'] as String,
      billId: row['bill_id'] as int?,
    );
  }

  Entry? entry(int entryId) {
    final rows = db.select('SELECT * FROM entry WHERE id = ? AND deleted = 0', [entryId]);
    return rows.isEmpty ? null : _entry(rows.first);
  }

  /// Who else is in a spend: friend name to amount, positive when they owe
  /// you and negative when you owe them.
  Map<String, int> splitOf(int entryId) {
    final rows = db.select(
      'SELECT f.name AS name, l.amount AS amount FROM ledger l JOIN friend f ON f.id = l.friend_id '
      "WHERE l.entry_id = ? AND l.deleted = 0 AND l.kind = 'split' ORDER BY l.id",
      [entryId],
    );
    return {for (final row in rows) row['name'] as String: row['amount'] as int};
  }

  /// Newest first.
  List<Entry> entriesForMonth(DateTime month) {
    final rows = db.select(
      'SELECT * FROM entry WHERE deleted = 0 AND substr(day, 1, 7) = ? '
      'ORDER BY day DESC, created_at DESC, id DESC',
      [monthKey(month)],
    );
    return rows.map(_entry).toList();
  }

  List<Entry> entriesForDay(DateTime day) {
    final rows = db.select(
      'SELECT * FROM entry WHERE deleted = 0 AND day = ? ORDER BY created_at DESC, id DESC',
      [dayKey(day)],
    );
    return rows.map(_entry).toList();
  }

  int spentInMonth(DateTime month) {
    final rows = db.select(
      'SELECT COALESCE(SUM(amount), 0) AS s FROM entry '
      'WHERE deleted = 0 AND substr(day, 1, 7) = ?',
      [monthKey(month)],
    );
    return rows.first['s'] as int;
  }

  int spentOnDay(DateTime day) {
    final rows = db.select(
      'SELECT COALESCE(SUM(amount), 0) AS s FROM entry WHERE deleted = 0 AND day = ?',
      [dayKey(day)],
    );
    return rows.first['s'] as int;
  }

  /// Category id to paise spent in [month], biggest first.
  Map<int, int> categoryTotals(DateTime month) {
    final rows = db.select(
      'SELECT category_id, SUM(amount) AS s FROM entry '
      'WHERE deleted = 0 AND substr(day, 1, 7) = ? '
      'GROUP BY category_id ORDER BY s DESC',
      [monthKey(month)],
    );
    return {for (final row in rows) row['category_id'] as int: row['s'] as int};
  }

  /// Paise spent on each day of [month]; index 0 is the 1st.
  List<int> dailyTotals(DateTime month) {
    final totals = List<int>.filled(daysInMonth(month), 0);
    final rows = db.select(
      'SELECT day, SUM(amount) AS s FROM entry '
      'WHERE deleted = 0 AND substr(day, 1, 7) = ? GROUP BY day',
      [monthKey(month)],
    );
    for (final row in rows) {
      final dayOfMonth = int.parse((row['day'] as String).substring(8));
      totals[dayOfMonth - 1] = row['s'] as int;
    }
    return totals;
  }
}
