import 'package:sqlite3/sqlite3.dart';

/// v7: private backup. Friends, spends, ledger lines and groups get a random
/// backup key (`bk`), and triggers put every change into `backup_queue`, so
/// no write path can forget to back itself up. `gen` grows with each change,
/// so a change made while an upload is in flight is never dropped.
void addBackup(Database db, void Function(String table, String column, String type) addColumn) {
  db.execute('''CREATE TABLE IF NOT EXISTS backup_queue (
    kind TEXT NOT NULL,
    bk TEXT NOT NULL,
    gen INTEGER NOT NULL,
    PRIMARY KEY (kind, bk))''');

  const tables = {
    'friend': ('friend', 'name, contact, user_id'),
    'entry': ('entry', 'title, amount, total, category_id, day, deleted, grp_id, remote_id, remote_by'),
    'ledger': ('ledger', 'friend_id, entry_id, title, amount, kind, day, deleted, remote_id'),
    'grp': ('group', 'name, deleted'),
  };

  // No OR REPLACE here: an outer statement's ON CONFLICT would override it.
  String queue(String kind, String bk) =>
      "UPDATE backup_queue SET gen = (SELECT MAX(gen) + 1 FROM backup_queue) WHERE kind = '$kind' AND bk = $bk; "
      "INSERT INTO backup_queue (kind, bk, gen) SELECT '$kind', $bk, (SELECT IFNULL(MAX(gen), 0) + 1 FROM backup_queue) "
      "WHERE $bk IS NOT NULL AND NOT EXISTS (SELECT 1 FROM backup_queue WHERE kind = '$kind' AND bk = $bk);";

  tables.forEach((table, spec) {
    final (kind, columns) = spec;
    addColumn(table, 'bk', 'TEXT');
    db.execute('UPDATE $table SET bk = lower(hex(randomblob(16))) WHERE bk IS NULL');
    db.execute('CREATE UNIQUE INDEX IF NOT EXISTS ${table}_bk ON $table(bk)');
    db.execute('''CREATE TRIGGER IF NOT EXISTS bk_${table}_add AFTER INSERT ON $table BEGIN
      UPDATE $table SET bk = lower(hex(randomblob(16))) WHERE id = NEW.id AND bk IS NULL;
      ${queue(kind, '(SELECT bk FROM $table WHERE id = NEW.id)')}
    END''');
    db.execute('''CREATE TRIGGER IF NOT EXISTS bk_${table}_change AFTER UPDATE OF $columns ON $table BEGIN
      ${queue(kind, 'NEW.bk')}
    END''');
    db.execute('''CREATE TRIGGER IF NOT EXISTS bk_${table}_gone AFTER DELETE ON $table BEGIN
      ${queue(kind, 'OLD.bk')}
    END''');
    db.execute("INSERT OR IGNORE INTO backup_queue (kind, bk, gen) SELECT '$kind', bk, 1 FROM $table");
  });

  // Shares belong to their spend, members to their group.
  for (final (table, parent, kind, link) in [
    ('entry_share', 'entry', 'entry', 'entry_id'),
    ('grp_member', 'grp', 'group', 'grp_id'),
  ]) {
    for (final (event, row) in [('INSERT', 'NEW'), ('UPDATE', 'NEW'), ('DELETE', 'OLD')]) {
      db.execute('''CREATE TRIGGER IF NOT EXISTS bk_${table}_${event.toLowerCase()} AFTER $event ON $table BEGIN
        ${queue(kind, '(SELECT bk FROM $parent WHERE id = $row.$link)')}
      END''');
    }
  }

  // The budget.
  for (final event in ['INSERT', 'UPDATE']) {
    db.execute('''CREATE TRIGGER IF NOT EXISTS bk_budget_${event.toLowerCase()} AFTER $event ON settings
      WHEN NEW.key = 'budget_paise' BEGIN
      ${queue('setting', "'budget'")}
    END''');
  }
  db.execute("INSERT OR IGNORE INTO backup_queue (kind, bk, gen) SELECT 'setting', 'budget', 1 FROM settings WHERE key = 'budget_paise'");
}
