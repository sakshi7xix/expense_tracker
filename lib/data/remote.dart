/// The online side of friends, as the app sees it. [SupabaseRemote] talks to
/// the server; tests use an in-memory fake.
library;

class RemoteExpense {
  const RemoteExpense({
    required this.id,
    required this.createdBy,
    required this.title,
    required this.total,
    required this.payer,
    required this.day,
    required this.deleted,
    required this.shares,
    required this.updatedAt,
  });

  final String id;
  final String createdBy;
  final String title;
  final int total;
  final String payer;

  /// 'YYYY-MM-DD'.
  final String day;
  final bool deleted;

  /// Account id to share in paise.
  final Map<String, int> shares;
  final String updatedAt;
}

class RemotePayment {
  const RemotePayment({
    required this.id,
    required this.from,
    required this.to,
    required this.amount,
    required this.day,
    required this.createdBy,
    required this.deleted,
    required this.updatedAt,
  });

  final String id;
  final String from;
  final String to;
  final int amount;
  final String day;
  final String createdBy;
  final bool deleted;
  final String updatedAt;
}

class FriendRequest {
  const FriendRequest({required this.id, required this.fromUser, required this.fromName, this.fromEmail = '', this.code});

  final String id;
  final String fromUser;
  final String fromName;

  /// Partly hidden, like ash•••@example.com. Empty when found by code.
  final String fromEmail;

  /// Only for requests from older app versions found by invite code.
  final String? code;
}

class SentInvite {
  const SentInvite({required this.id, required this.status, this.acceptedBy, this.toUser, this.toName = ''});

  final String id;

  /// Who the request went to, and their name.
  final String? toUser;
  final String toName;

  /// pending, accepted, declined or blocked. Declined and blocked look like
  /// pending to the sender.
  final String status;
  final String? acceptedBy;
}

/// One thing from the phone in your private backup: a friend, spend, ledger
/// line, group or setting. [data] `{"gone": true}` means it was removed.
class BackupRow {
  const BackupRow(this.kind, this.key, this.data);

  final String kind;
  final String key;
  final Map<String, Object?> data;
}

/// A failure fit to show as it is.
class RemoteFailure implements Exception {
  const RemoteFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract class Remote {
  /// This account's personal friend code.
  Future<String> myCode();

  /// Sends a friend request to whoever owns [code]. Returns their id, name and
  /// whether you're now friends already (they had asked you first).
  Future<({String toUser, String toName, bool accepted})> requestFriend(String code);

  Future<List<SentInvite>> sentInvites();
  Future<List<FriendRequest>> requests();

  /// [answer] is accepted, declined or blocked. Returns the sender's id.
  Future<String> answer(String inviteId, String? code, String answer);

  /// Display names for account ids (friends and people sharing an expense).
  Future<Map<String, String>> names(Iterable<String> userIds);

  Future<void> saveExpense({
    required String id,
    required String title,
    required int total,
    required String payer,
    required String day,
    required Map<String, int> shares,
  });

  Future<void> deleteExpense(String id, {bool deleted = true});
  Future<void> savePayment({required String id, required String from, required String to, required int amount, required String day});

  /// Changes since [since] (an `updatedAt` from an earlier result), oldest first.
  Future<List<RemoteExpense>> expensesSince(String? since);
  Future<List<RemotePayment>> paymentsSince(String? since);

  /// Saves rows to your private backup, replacing any with the same kind and key.
  Future<void> saveBackup(List<BackupRow> rows);

  /// Everything in your private backup.
  Future<List<BackupRow>> loadBackup();
}
