import 'dart:math' as math;

import 'package:sqlite3/sqlite3.dart';

import '../core/dates.dart';
import 'models.dart';

part 'store_bills.dart';
part 'store_friends.dart';
part 'store_spends.dart';

/// All reads and writes go through here. Synchronous, local-only.
class StubStore {
  StubStore(this.db, {DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final Database db;
  final DateTime Function() _clock;

  int get _now => _clock().millisecondsSinceEpoch;

  T _tx<T>(T Function() body) {
    db.execute('BEGIN');
    try {
      final result = body();
      db.execute('COMMIT');
      return result;
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }
  }

  int _insert(String sql, List<Object?> args) {
    db.execute(sql, args);
    return db.lastInsertRowId;
  }

  String? _setting(String key) {
    final rows = db.select('SELECT value FROM settings WHERE key = ?', [key]);
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  void _setSetting(String key, String value) {
    db.execute(
      'INSERT INTO settings (key, value) VALUES (?, ?) '
      'ON CONFLICT(key) DO UPDATE SET value = excluded.value',
      [key, value],
    );
  }

  /// Monthly budget in paise. Zero until the welcome screen sets it.
  int get budget => int.tryParse(_setting('budget_paise') ?? '') ?? 0;
  set budget(int paise) => _setSetting('budget_paise', '$paise');

  bool get firstRunDone => _setting('first_run_done') == '1';
  set firstRunDone(bool done) => _setSetting('first_run_done', done ? '1' : '0');

  List<Category> categories() {
    return [
      for (final row in db.select('SELECT id, name FROM category ORDER BY sort, id'))
        Category(id: row['id'] as int, name: row['name'] as String),
    ];
  }
}
