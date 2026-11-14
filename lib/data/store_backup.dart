part of 'store.dart';

/// Rows to back up, with the change number each was read at.
class BackupBatch {
  const BackupBatch(this.rows, this.gens);

  final List<BackupRow> rows;
  final List<int> gens;

  bool get isEmpty => rows.isEmpty;
}

const _gone = {'gone': true};

extension BackupStore on StubStore {
  /// Set once this phone has brought in the account's backup.
  bool get backupRestored => _setting('backup_restored') == accountId && accountId != null;
  set backupRestored(bool done) => _setSetting('backup_restored', done ? accountId ?? '' : '');

  /// When the last backup finished, in ms since epoch; null if never.
  int? get backedUpAt => int.tryParse(_setting('backed_up_at') ?? '');
  void markBackedUp() => _setSetting('backed_up_at', '$_now');

  int get backupWaiting => db.select('SELECT COUNT(*) AS n FROM backup_queue').first['n'] as int;

  String? _bk(String table, Object? id) {
    if (id == null) return null;
    final rows = db.select('SELECT bk FROM $table WHERE id = ?', [id]);
    return rows.isEmpty ? null : rows.first['bk'] as String?;
  }

  /// Up to [limit] changed things, as they are now.
  BackupBatch pendingBackup({int limit = 400}) {
    final rows = <BackupRow>[];
    final gens = <int>[];
    for (final q in db.select('SELECT kind, bk, gen FROM backup_queue ORDER BY gen LIMIT ?', [limit])) {
      final kind = q['kind'] as String;
      final bk = q['bk'] as String;
      rows.add(BackupRow(kind, bk, _backupData(kind, bk) ?? _gone));
      gens.add(q['gen'] as int);
    }
    return BackupBatch(rows, gens);
  }

  /// Marks a batch as saved. Anything changed again since stays queued.
  void backedUp(BackupBatch batch) {
    _tx(() {
      for (var i = 0; i < batch.rows.length; i++) {
        db.execute('DELETE FROM backup_queue WHERE kind = ? AND bk = ? AND gen <= ?', [batch.rows[i].kind, batch.rows[i].key, batch.gens[i]]);
      }
    });
  }

  Map<String, Object?>? _backupData(String kind, String bk) {
    switch (kind) {
      case 'setting':
        return bk == 'budget' ? {'value': budget} : null;
      case 'friend':
        final r = db.select('SELECT * FROM friend WHERE bk = ?', [bk]).firstOrNull;
        return r == null ? null : {'name': r['name'], 'contact': r['contact'], 'user_id': r['user_id']};
      case 'group':
        final r = db.select('SELECT * FROM grp WHERE bk = ?', [bk]).firstOrNull;
        if (r == null) return null;
        return {
          'name': r['name'],
          'deleted': r['deleted'],
          'members': [
            for (final m in db.select('SELECT f.bk FROM grp_member g JOIN friend f ON f.id = g.friend_id WHERE g.grp_id = ?', [r['id']])) m['bk'],
          ],
        };
      case 'entry':
        final r = db.select('SELECT e.*, c.name AS category FROM entry e JOIN category c ON c.id = e.category_id WHERE e.bk = ?', [bk]).firstOrNull;
        if (r == null) return null;
        return {
          for (final k in ['title', 'amount', 'total', 'category', 'day', 'created_at', 'deleted', 'remote_id', 'remote_by']) k: r[k],
          'group': _bk('grp', r['grp_id']),
          'shares': {
            for (final s in db.select('SELECT f.bk, s.share FROM entry_share s JOIN friend f ON f.id = s.friend_id WHERE s.entry_id = ?', [r['id']]))
              s['bk'] as String: s['share'],
          },
        };
      case 'ledger':
        final r = db.select('SELECT * FROM ledger WHERE bk = ?', [bk]).firstOrNull;
        if (r == null) return null;
        return {
          for (final k in ['title', 'amount', 'kind', 'day', 'created_at', 'deleted', 'remote_id']) k: r[k],
          'friend': _bk('friend', r['friend_id']),
          'entry': _bk('entry', r['entry_id']),
        };
    }
    return null;
  }

  /// Brings a backup onto this phone, keeping whatever is already here.
  /// Returns how many spends came back.
  int restoreBackup(List<BackupRow> rows) {
    final byKind = <String, List<BackupRow>>{};
    for (final r in rows) {
      if (r.data['gone'] != true) byKind.putIfAbsent(r.kind, () => []).add(r);
    }
    final restored = <(String, String)>[];
    int? local(String table, String bk) => db.select('SELECT id FROM $table WHERE bk = ?', [bk]).firstOrNull?['id'] as int?;
    int flag(Object? v) => v == true || v == 1 ? 1 : 0;

    return _tx(() {
      var spends = 0;
      for (final r in byKind['setting'] ?? const <BackupRow>[]) {
        final value = (r.data['value'] as num?)?.toInt() ?? 0;
        if (r.key == 'budget' && budget == 0 && value > 0) {
          budget = value;
          restored.add(('setting', r.key));
        }
      }

      final friends = <String, int>{};
      for (final r in byKind['friend'] ?? const <BackupRow>[]) {
        final name = '${r.data['name'] ?? ''}'.trim();
        final userId = r.data['user_id'] as String?;
        final same = local('friend', r.key) ??
            (userId == null ? null : friendIdForUser(userId)) ??
            db.select('SELECT id FROM friend WHERE name = ?', [name]).firstOrNull?['id'] as int?;
        if (same != null) {
          friends[r.key] = same;
          continue;
        }
        if (name.isEmpty) continue;
        friends[r.key] = _insert('INSERT INTO friend (name, contact, user_id, bk) VALUES (?, ?, ?, ?)', [name, r.data['contact'] ?? '', userId, r.key]);
        restored.add(('friend', r.key));
      }

      final groups = <String, int>{};
      for (final r in byKind['group'] ?? const <BackupRow>[]) {
        final known = local('grp', r.key);
        if (known != null) {
          groups[r.key] = known;
          continue;
        }
        final id = _insert('INSERT INTO grp (name, deleted, bk) VALUES (?, ?, ?)', ['${r.data['name'] ?? 'Group'}', flag(r.data['deleted']), r.key]);
        for (final m in (r.data['members'] as List? ?? const [])) {
          final f = friends[m];
          if (f != null) db.execute('INSERT OR IGNORE INTO grp_member (grp_id, friend_id) VALUES (?, ?)', [id, f]);
        }
        groups[r.key] = id;
        restored.add(('group', r.key));
      }

      final cats = {for (final c in categories()) c.name: c.id};
      final other = cats['Other'] ?? cats.values.last;
      final entries = <String, int>{};
      for (final r in byKind['entry'] ?? const <BackupRow>[]) {
        final d = r.data;
        final remoteId = d['remote_id'] as String?;
        final known = local('entry', r.key) ??
            (remoteId == null ? null : db.select('SELECT id FROM entry WHERE remote_id = ?', [remoteId]).firstOrNull?['id'] as int?);
        if (known != null) {
          entries[r.key] = known;
          continue;
        }
        final id = _insert(
          'INSERT INTO entry (title, amount, total, category_id, day, created_at, deleted, grp_id, remote_id, remote_by, bk) '
          'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
          [
            '${d['title'] ?? ''}', (d['amount'] as num).toInt(), (d['total'] as num).toInt(), cats[d['category']] ?? other,
            d['day'], (d['created_at'] as num?)?.toInt() ?? _now, flag(d['deleted']), groups[d['group']], remoteId, d['remote_by'], r.key,
          ],
        );
        (d['shares'] as Map? ?? const {}).forEach((friendBk, share) {
          final f = friends[friendBk];
          if (f != null) db.execute('INSERT OR IGNORE INTO entry_share (entry_id, friend_id, share) VALUES (?, ?, ?)', [id, f, (share as num).toInt()]);
        });
        entries[r.key] = id;
        restored.add(('entry', r.key));
        if (flag(d['deleted']) == 0) spends++;
      }

      for (final r in byKind['ledger'] ?? const <BackupRow>[]) {
        final d = r.data;
        final friend = friends[d['friend']];
        final remoteId = d['remote_id'] as String?;
        if (friend == null || local('ledger', r.key) != null) continue;
        if (remoteId != null && db.select('SELECT 1 FROM ledger WHERE remote_id = ?', [remoteId]).isNotEmpty) continue;
        _insert(
          'INSERT INTO ledger (friend_id, entry_id, title, amount, kind, day, created_at, deleted, remote_id, bk) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
          [
            friend, entries[d['entry']], '${d['title'] ?? ''}', (d['amount'] as num).toInt(), d['kind'] ?? 'split', d['day'],
            (d['created_at'] as num?)?.toInt() ?? _now, flag(d['deleted']), remoteId, r.key,
          ],
        );
        restored.add(('ledger', r.key));
      }

      // What just came from the backup is already there.
      for (final (kind, key) in restored) {
        db.execute('DELETE FROM backup_queue WHERE kind = ? AND bk = ?', [kind, key]);
      }
      return spends;
    });
  }
}
