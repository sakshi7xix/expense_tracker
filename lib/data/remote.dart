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

  /// Set when the request was found by its invite code.
  final String? code;
}

class SentInvite {
  const SentInvite({required this.id, required this.code, required this.status, this.acceptedBy});

  final String id;
  final String code;

  /// pending, accepted, declined or blocked. Declined and blocked look like
  /// pending to the sender.
  final String status;
  final String? acceptedBy;
}

/// A failure fit to show as it is.
class RemoteFailure implements Exception {
  const RemoteFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract class Remote {
  Future<({String id, String code})> createInvite(String friendName, String? email);
  Future<List<SentInvite>> sentInvites();
  Future<List<FriendRequest>> requests();
  Future<FriendRequest?> inviteByCode(String code);

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
}
