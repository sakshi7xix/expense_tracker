import 'package:sqlite3/sqlite3.dart';

const schemaVersion = 2;

const defaultCategories = [
  'Food', 'Groceries', 'Café', 'Travel', 'Shopping', 'Fun', 'Home',
  'Rent', 'Utilities', 'Electricity', 'Subscriptions', 'Health', 'Study', 'Other',
];

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
  // v2: the full category list, in display order. Existing ones are kept.
  for (var i = 0; i < defaultCategories.length; i++) {
    db.execute('INSERT OR IGNORE INTO category (name, sort) VALUES (?, ?)', [defaultCategories[i], i]);
    db.execute('UPDATE category SET sort = ? WHERE name = ?', [i, defaultCategories[i]]);
  }
  db.userVersion = schemaVersion;
  db.execute('COMMIT');
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
