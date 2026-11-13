part of 'store.dart';

extension Bills on StubStore {
  int addBill({
    required String name,
    required int amount,
    required int dueDay,
    required int categoryId,
    bool autopay = false,
  }) {
    if (amount <= 0 || dueDay < 1 || dueDay > 31) {
      throw ArgumentError('A bill needs an amount and a day of the month');
    }
    return _insert(
      'INSERT INTO bill (name, amount, due_day, autopay, category_id) VALUES (?, ?, ?, ?, ?)',
      [name.trim(), amount, dueDay, autopay ? 1 : 0, categoryId],
    );
  }

  void updateBill(
    int billId, {
    required String name,
    required int amount,
    required int dueDay,
    required bool autopay,
  }) {
    db.execute(
      'UPDATE bill SET name = ?, amount = ?, due_day = ?, autopay = ? WHERE id = ?',
      [name.trim(), amount, dueDay, autopay ? 1 : 0, billId],
    );
  }

  /// Stops a bill from now on. Spends it already created stay.
  void removeBill(int billId) {
    db.execute('UPDATE bill SET active = 0 WHERE id = ?', [billId]);
  }

  /// Every active bill with its state in [month], ordered by due day.
  List<BillStatus> billsFor(DateTime month) {
    final rows = db.select(
      'SELECT b.*, p.skipped AS skipped, p.bill_id AS has_payment '
      'FROM bill b LEFT JOIN bill_payment p ON p.bill_id = b.id AND p.month = ? '
      'WHERE b.active = 1 ORDER BY b.due_day, b.id',
      [monthKey(month)],
    );
    return [
      for (final row in rows)
        BillStatus(
          id: row['id'] as int,
          name: row['name'] as String,
          amount: row['amount'] as int,
          dueDay: row['due_day'] as int,
          autopay: (row['autopay'] as int) == 1,
          categoryId: row['category_id'] as int,
          state: row['has_payment'] == null
              ? BillState.due
              : (row['skipped'] as int) == 1
                  ? BillState.skipped
                  : BillState.paid,
        ),
    ];
  }

  /// Money still to go out on bills this month, in paise.
  int committedFor(DateTime month) {
    return billsFor(month)
        .where((b) => b.state == BillState.due)
        .fold(0, (sum, b) => sum + b.amount);
  }

  /// Pays a bill for the month of [day]: logs the spend on [day] and marks it
  /// paid. Returns the new entry id, or null if it was already handled.
  int? payBill(int billId, {required DateTime day}) {
    final bill = billsFor(day).where((b) => b.id == billId).firstOrNull;
    if (bill == null || bill.state != BillState.due) return null;
    final entryId = addSpend(
      title: bill.name,
      total: bill.amount,
      categoryId: bill.categoryId,
      day: day,
      billId: bill.id,
    );
    db.execute(
      'INSERT INTO bill_payment (bill_id, month, entry_id) VALUES (?, ?, ?)',
      [bill.id, monthKey(day), entryId],
    );
    return entryId;
  }

  void skipBill(int billId, {required DateTime month}) {
    db.execute(
      'INSERT OR IGNORE INTO bill_payment (bill_id, month, skipped) VALUES (?, ?, 1)',
      [billId, monthKey(month)],
    );
  }

  /// Logs every autopay whose day has come this month and is not yet paid
  /// or skipped. Safe to call on every app open. Returns the new entry ids.
  List<int> runAutopays(DateTime today) {
    final lastDay = daysInMonth(today);
    final created = <int>[];
    for (final bill in billsFor(today)) {
      if (!bill.autopay || bill.state != BillState.due) continue;
      final dueDay = math.min(bill.dueDay, lastDay);
      if (dueDay > today.day) continue;
      final id = payBill(bill.id, day: DateTime(today.year, today.month, dueDay));
      if (id != null) created.add(id);
    }
    return created;
  }
}
