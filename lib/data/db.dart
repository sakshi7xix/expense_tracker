import 'package:sqlite3/sqlite3.dart';

const schemaVersion = 6;

const defaultCategories = [
  'Food', 'Groceries', 'Transport', 'Shopping',
  'Rent', 'Electricity', 'Water & gas', 'Internet & mobile', 'Subscriptions',
  'Health', 'Education', 'Personal care', 'Entertainment', 'Trips', 'Gifts',
  'Investments',
  'Other',
];

/// Older category names and where they went in v3.
const _renamed = {'Travel': 'Transport', 'Fun': 'Entertainment', 'Study': 'Education', 'Utilities': 'Water & gas'};
const _merged = {'Café': 'Food', 'Home': 'Other'};

/// A fresh in-memory database, used by tests.
Database openMemoryDb() {
  final db = sqlite3.openInMemory();
  migrate(db);
  return db;
}

Database openFileDb(String path) {
  final db = sqlite3.open(path);
  migrate(db);
  return db;
}

/// Creates the schema on first open and upgrades older databases.
/// Amounts are whole paise; days are 'YYYY-MM-DD' text; rows are
/// soft-deleted with `deleted = 1`.
void migrate(Database db) {
  db.execute('PRAGMA foreign_keys = ON');
  final from = db.userVersion;
  if (from >= schemaVersion) return;
  db.execute('BEGIN');
  if (from < 1) {
    for (final statement in _v1) {
      db.execute(statement);
    }
  }
  if (from >= 1) _refineCategories(db);
  for (var i = 0; i < defaultCategories.length; i++) {
    db.execute('INSERT OR IGNORE INTO category (name, sort) VALUES (?, ?)', [defaultCategories[i], i]);
    db.execute('UPDATE category SET sort = ? WHERE name = ?', [i, defaultCategories[i]]);
  }
  if (from >= 1) {
    _merged.forEach((old, into) => _merge(db, old, into));
  }
  if (from < 4) {
    // v4: a spend can belong to a group, and groups can be removed.
    _addColumn(db, 'entry', 'grp_id', 'INTEGER REFERENCES grp(id)');
    _addColumn(db, 'grp', 'deleted', 'INTEGER NOT NULL DEFAULT 0');
  }
  if (from < 5) {
    // v5: friends online. Friends can be linked to an account, spends and
    // payments remember their online copy, and changes waiting to upload are
    // marked dirty. Each friend's share of a spend is kept, and the bell's
    // notices are stored.
    _addColumn(db, 'friend', 'user_id', 'TEXT');
    _addColumn(db, 'friend', 'invite_id', 'TEXT');
    _addColumn(db, 'friend', 'invite_code', 'TEXT');
    _addColumn(db, 'entry', 'remote_id', 'TEXT');
    _addColumn(db, 'entry', 'remote_by', 'TEXT');
    _addColumn(db, 'entry', 'dirty', 'INTEGER NOT NULL DEFAULT 0');
    _addColumn(db, 'ledger', 'remote_id', 'TEXT');
    _addColumn(db, 'ledger', 'dirty', 'INTEGER NOT NULL DEFAULT 0');
    db.execute('''CREATE TABLE IF NOT EXISTS entry_share (
      entry_id INTEGER NOT NULL REFERENCES entry(id),
      friend_id INTEGER NOT NULL REFERENCES friend(id),
      share INTEGER NOT NULL,
      PRIMARY KEY (entry_id, friend_id))''');
    db.execute('''CREATE TABLE IF NOT EXISTS notice (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      ref TEXT NOT NULL UNIQUE,
      title TEXT NOT NULL,
      sub TEXT NOT NULL,
      who TEXT NOT NULL,
      at INTEGER NOT NULL,
      seen INTEGER NOT NULL DEFAULT 0)''');
    db.execute('CREATE UNIQUE INDEX IF NOT EXISTS entry_remote ON entry(remote_id) WHERE remote_id IS NOT NULL');
    db.execute('CREATE UNIQUE INDEX IF NOT EXISTS ledger_remote ON ledger(remote_id) WHERE remote_id IS NOT NULL');
  }
  db.userVersion = schemaVersion;
  db.execute('COMMIT');
}

void _addColumn(Database db, String table, String column, String type) {
  final exists = db.select('PRAGMA table_info($table)').any((row) => row['name'] == column);
  if (!exists) db.execute('ALTER TABLE $table ADD COLUMN $column $type');
}

int? _categoryId(Database db, String name) {
  final rows = db.select('SELECT id FROM category WHERE name = ?', [name]);
  return rows.isEmpty ? null : rows.first['id'] as int;
}

/// Renames old categories to their v3 names, keeping every spend and bill.
void _refineCategories(Database db) {
  _renamed.forEach((old, into) {
    if (_categoryId(db, old) == null) return;
    if (_categoryId(db, into) == null) {
      db.execute('UPDATE category SET name = ? WHERE name = ?', [into, old]);
    } else {
      _merge(db, old, into);
    }
  });
}

/// Moves every spend and bill from [old] to [into], then drops [old].
void _merge(Database db, String old, String into) {
  final from = _categoryId(db, old);
  final to = _categoryId(db, into);
  if (from == null || to == null) return;
  db.execute('UPDATE entry SET category_id = ? WHERE category_id = ?', [to, from]);
  db.execute('UPDATE bill SET category_id = ? WHERE category_id = ?', [to, from]);
  db.execute('DELETE FROM category WHERE id = ?', [from]);
}

const _v1 = [
  'CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
  '''CREATE TABLE category (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE,
    sort INTEGER NOT NULL DEFAULT 0)''',
  // amount = your own share (what counts against the budget); total = the full bill.
  '''CREATE TABLE entry (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    title TEXT NOT NULL,
    amount INTEGER NOT NULL,
    total INTEGER NOT NULL,
    category_id INTEGER NOT NULL REFERENCES category(id),
    day TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    bill_id INTEGER,
    deleted INTEGER NOT NULL DEFAULT 0)''',
  'CREATE INDEX entry_day ON entry(day)',
  '''CREATE TABLE friend (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE COLLATE NOCASE,
    contact TEXT NOT NULL DEFAULT '',
    joined INTEGER NOT NULL DEFAULT 0)''',
  // amount > 0: the friend owes you. amount < 0: you owe the friend.
  '''CREATE TABLE ledger (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    friend_id INTEGER NOT NULL REFERENCES friend(id),
    entry_id INTEGER REFERENCES entry(id),
    title TEXT NOT NULL,
    amount INTEGER NOT NULL,
    kind TEXT NOT NULL,
    day TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    deleted INTEGER NOT NULL DEFAULT 0)''',
  'CREATE INDEX ledger_friend ON ledger(friend_id)',
  'CREATE TABLE grp (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL)',
  '''CREATE TABLE grp_member (
    grp_id INTEGER NOT NULL REFERENCES grp(id),
    friend_id INTEGER NOT NULL REFERENCES friend(id),
    PRIMARY KEY (grp_id, friend_id))''',
  '''CREATE TABLE bill (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    amount INTEGER NOT NULL,
    due_day INTEGER NOT NULL,
    autopay INTEGER NOT NULL DEFAULT 0,
    category_id INTEGER NOT NULL REFERENCES category(id),
    active INTEGER NOT NULL DEFAULT 1)''',
  // One row per bill per month once it is paid or skipped.
  '''CREATE TABLE bill_payment (
    bill_id INTEGER NOT NULL REFERENCES bill(id),
    month TEXT NOT NULL,
    entry_id INTEGER REFERENCES entry(id),
    skipped INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (bill_id, month))''',
];
