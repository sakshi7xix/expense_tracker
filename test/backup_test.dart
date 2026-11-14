import 'package:flutter_test/flutter_test.dart';
import 'package:stub/data/db.dart';
import 'package:stub/data/store.dart';
import 'package:stub/data/sync.dart';
import 'package:stub/features/settings/backup_status.dart';
import 'package:sqlite3/sqlite3.dart';

import 'fake_remote.dart';

void main() {
  late FakeServer server;
  final nov = DateTime(2026, 11, 10);
  final oct = DateTime(2026, 10, 3);

  setUp(() {
    server = FakeServer()
      ..addUser('A', 'asha@example.com', 'Asha', code: 'ASHA2345')
      ..addUser('B', 'bina@example.com', 'Bina', code: 'BINA6789');
  });

  Sync syncFor(StubStore store, String me) => Sync(store: store, remote: FakeRemote(server, me), me: me, onChanged: () {});
  int cat(StubStore s, String name) => s.categories().firstWhere((c) => c.name == name).id;

  test('every change waits in the queue until it is backed up', () {
    final s = StubStore(openMemoryDb());
    expect(s.backupWaiting, 0);
    s.addSpend(title: 'Chai', total: 4000, categoryId: cat(s, 'Food'), day: nov);
    s.budget = 3000000;
    final batch = s.pendingBackup();
    expect({for (final r in batch.rows) r.kind}, {'entry', 'setting'});
    expect(batch.rows.firstWhere((r) => r.kind == 'entry').data['title'], 'Chai');

    // Changed again while the upload was on its way: it stays queued.
    final id = s.entriesForMonth(nov).single.id;
    s.updateSpend(id, title: 'Masala chai', total: 4000, categoryId: cat(s, 'Food'), friendShares: const {});
    s.backedUp(batch);
    final again = s.pendingBackup();
    expect(again.rows.single.data['title'], 'Masala chai');
    s.backedUp(again);
    expect(s.backupWaiting, 0);

    s.deleteSpend(id);
    expect(s.pendingBackup().rows.single.data['deleted'], 1);
  });

  test('an older phone backs up what it already had', () {
    // Build a v6 database by taking the backup parts off a new one.
    final db = sqlite3.openInMemory();
    migrate(db);
    for (final r in db.select("SELECT name FROM sqlite_master WHERE type = 'trigger'")) {
      db.execute('DROP TRIGGER ${r['name']}');
    }
    db.execute('DROP TABLE backup_queue');
    for (final t in ['friend', 'entry', 'ledger', 'grp']) {
      db.execute('DROP INDEX ${t}_bk');
      db.execute('ALTER TABLE $t DROP COLUMN bk');
    }
    db.userVersion = 6;
    db.execute("INSERT INTO entry (title, amount, total, category_id, day, created_at) VALUES ('Rent', 1500000, 1500000, 1, '2026-10-03', 0)");
    db.execute("INSERT INTO settings (key, value) VALUES ('budget_paise', '2000000')");

    migrate(db);
    final rows = StubStore(db).pendingBackup().rows;
    expect(rows.firstWhere((r) => r.kind == 'entry').data['title'], 'Rent');
    expect(rows.firstWhere((r) => r.kind == 'setting').data['value'], 2000000);
  });

  test('a reinstalled phone gets back every month, friends and balances', () async {
    final phone = StubStore(openMemoryDb());
    phone.budget = 2500000;
    final riya = phone.addFriend('Riya');
    phone.addSpend(title: 'Rent', total: 1500000, categoryId: cat(phone, 'Rent'), day: oct);
    phone.addSpend(title: 'Dinner', total: 120000, categoryId: cat(phone, 'Food'), day: nov, friendShares: {riya: 60000});
    phone.settle(riya, 20000, day: nov);
    phone.addGroup('Flatmates', [riya]);
    await syncFor(phone, 'A').run();
    expect(server.backups['A']!.length, greaterThanOrEqualTo(6));
    expect(phone.backupWaiting, 0);
    expect(phone.backedUpAt, isNotNull);

    // The app is deleted and installed again.
    final fresh = StubStore(openMemoryDb());
    await syncFor(fresh, 'A').run();
    expect(fresh.budget, 2500000);
    expect(fresh.entriesForMonth(oct).single.title, 'Rent');
    expect(fresh.entriesForMonth(nov).single.amount, 60000);
    expect(fresh.friends().single.name, 'Riya');
    expect(fresh.friends().single.balance, phone.friends().single.balance);
    expect(fresh.groups().single.name, 'Flatmates');
    expect(fresh.notices().first.title, 'Your spends are back');
    expect(fresh.backupWaiting, 0, reason: 'what came from the backup isn’t uploaded again');

    // Syncing again doesn't bring anything in twice.
    await syncFor(fresh, 'A').run();
    expect(fresh.entriesForMonth(oct), hasLength(1));
    expect(fresh.friends(), hasLength(1));
  });

  test('spends added before signing in are kept alongside the backup', () async {
    final old = StubStore(openMemoryDb())..addSpend(title: 'Rent', total: 1500000, categoryId: 1, day: oct);
    await syncFor(old, 'A').run();

    final fresh = StubStore(openMemoryDb())..addSpend(title: 'Auto', total: 9000, categoryId: 1, day: nov);
    await syncFor(fresh, 'A').run();
    expect(fresh.entriesForMonth(oct).single.title, 'Rent');
    expect(fresh.entriesForMonth(nov).single.title, 'Auto');
    expect(server.backups['A']!.values.where((r) => r.kind == 'entry'), hasLength(2));
  });

  test('a deleted spend stays deleted after restoring', () async {
    final phone = StubStore(openMemoryDb());
    final id = phone.addSpend(title: 'Oops', total: 5000, categoryId: 1, day: nov);
    phone.deleteSpend(id);
    await syncFor(phone, 'A').run();
    final fresh = StubStore(openMemoryDb());
    await syncFor(fresh, 'A').run();
    expect(fresh.entriesForMonth(nov), isEmpty);
  });

  test('one account never sees another’s backup', () async {
    final asha = StubStore(openMemoryDb())..addSpend(title: 'Rent', total: 1500000, categoryId: 1, day: oct);
    await syncFor(asha, 'A').run();
    final bina = StubStore(openMemoryDb());
    await syncFor(bina, 'B').run();
    expect(bina.entriesForMonth(oct), isEmpty);
  });

  test('the Settings line says how the backup is doing', () {
    final now = DateTime(2026, 11, 14, 12);
    String line({bool signedIn = true, bool running = false, String? problem, int? at, int waiting = 0}) =>
        backupStatus(signedIn: signedIn, running: running, problem: problem, backedUpAt: at, waiting: waiting, now: now);
    expect(line(signedIn: false), startsWith('Off'));
    expect(line(running: true, waiting: 3), 'Backing up…');
    expect(line(problem: 'offline', waiting: 2), contains('2 changes'));
    expect(line(at: now.subtract(Duration(minutes: 5)).millisecondsSinceEpoch), endsWith('5 min ago.'));
    expect(line(at: now.millisecondsSinceEpoch), endsWith('just now.'));
  });
}
