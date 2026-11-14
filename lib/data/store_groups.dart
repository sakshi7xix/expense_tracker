part of 'store.dart';

extension Groups on StubStore {
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

  /// Adds friends to a group; ones already in it are ignored.
  void addGroupMembers(int groupId, Iterable<int> friendIds) {
    for (final friendId in friendIds) {
      db.execute('INSERT OR IGNORE INTO grp_member (grp_id, friend_id) VALUES (?, ?)', [groupId, friendId]);
    }
  }

  /// Hides a group. Its spends and balances stay.
  void removeGroup(int groupId) {
    db.execute('UPDATE grp SET deleted = 1 WHERE id = ?', [groupId]);
  }

  List<Group> groups() {
    return [
      for (final row in db.select('SELECT id, name FROM grp WHERE deleted = 0 ORDER BY id'))
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

  /// The group's spends, newest first.
  List<Entry> groupEntries(int groupId, {int limit = 50}) {
    final rows = db.select(
      'SELECT * FROM entry WHERE deleted = 0 AND grp_id = ? '
      'ORDER BY day DESC, created_at DESC, id DESC LIMIT ?',
      [groupId, limit],
    );
    return rows.map(_entry).toList();
  }

  GroupSummary groupSummary(int groupId) {
    final spent = db.select(
      'SELECT COALESCE(SUM(total), 0) AS s FROM entry WHERE deleted = 0 AND grp_id = ?',
      [groupId],
    ).first['s'] as int;
    final rows = db.select(
      'SELECT l.friend_id AS f, SUM(l.amount) AS b FROM ledger l JOIN entry e ON e.id = l.entry_id '
      'WHERE l.deleted = 0 AND e.grp_id = ? GROUP BY l.friend_id',
      [groupId],
    );
    return GroupSummary(
      spent: spent,
      balances: {for (final row in rows) row['f'] as int: row['b'] as int},
    );
  }
}
