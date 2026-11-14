import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'remote.dart';

/// [Remote] on Supabase. Writes go through the database functions in
/// supabase/migrations, which check friendship and that shares add up.
class SupabaseRemote implements Remote {
  SupabaseRemote(this._client);

  final SupabaseClient _client;

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on SocketException {
      throw const RemoteFailure('No internet connection.');
    } on PostgrestException catch (e) {
      final m = e.message;
      if (m.contains('too many')) throw const RemoteFailure('That’s a lot of requests today. Try again tomorrow.');
      if (m.contains('no one has that code')) throw const RemoteFailure('No one has that code. Check it with your friend.');
      if (m.contains('your own code')) throw const RemoteFailure('That’s your own code.');
      if (m.contains('already friends')) throw const RemoteFailure('You’re already friends.');
      if (m.contains('backup is full')) throw const RemoteFailure('Your backup is full. Write to us and we’ll help.');
      if (m.contains('invite not found')) throw const RemoteFailure('That request was already answered.');
      throw RemoteFailure(m);
    } on AuthException catch (e) {
      throw RemoteFailure(e.message);
    }
  }

  @override
  Future<String> myCode() => _guard(() async {
        final id = _client.auth.currentUser!.id;
        final row = await _client.from('profiles').select('friend_code').eq('id', id).single();
        return row['friend_code'] as String;
      });

  @override
  Future<({String toUser, String toName, bool accepted})> requestFriend(String code) => _guard(() async {
        final rows = await _client.rpc('request_friend', params: {'p_code': code}) as List;
        final r = rows.first as Map;
        return (toUser: r['to_user'] as String, toName: r['to_name'] as String, accepted: r['status'] == 'accepted');
      });

  @override
  Future<List<SentInvite>> sentInvites() => _guard(() async {
        final rows = await _client.from('invites').select('id, status, accepted_by, to_user, friend_name');
        return [
          for (final r in rows)
            SentInvite(
              id: r['id'] as String,
              status: r['status'] as String,
              acceptedBy: r['accepted_by'] as String?,
              toUser: r['to_user'] as String?,
              toName: r['friend_name'] as String? ?? '',
            ),
        ];
      });

  @override
  Future<List<FriendRequest>> requests() => _guard(() async {
        final rows = await _client.rpc('my_requests') as List;
        return [
          for (final r in rows.cast<Map>())
            FriendRequest(
              id: r['id'] as String,
              fromUser: r['from_user'] as String,
              fromName: r['from_name'] as String,
              fromEmail: r['from_email'] as String? ?? '',
            ),
        ];
      });

  @override
  Future<String> answer(String inviteId, String? code, String answer) => _guard(() async {
        return await _client.rpc('answer_invite', params: {'p_id': inviteId, 'p_code': code, 'p_answer': answer}) as String;
      });

  @override
  Future<Map<String, String>> names(Iterable<String> userIds) => _guard(() async {
        final rows = await _client.from('profiles').select('id, name').inFilter('id', userIds.toList());
        return {for (final r in rows) r['id'] as String: r['name'] as String};
      });

  @override
  Future<void> saveExpense({
    required String id,
    required String title,
    required int total,
    required String payer,
    required String day,
    required Map<String, int> shares,
  }) =>
      _guard(() => _client.rpc('save_expense', params: {
            'p_id': id,
            'p_title': title,
            'p_total': total,
            'p_payer': payer,
            'p_day': day,
            'p_shares': shares,
          }));

  @override
  Future<void> deleteExpense(String id, {bool deleted = true}) =>
      _guard(() => _client.rpc('delete_expense', params: {'p_id': id, 'p_deleted': deleted}));

  @override
  Future<void> savePayment({required String id, required String from, required String to, required int amount, required String day}) =>
      _guard(() => _client.rpc('save_payment', params: {'p_id': id, 'p_from': from, 'p_to': to, 'p_amount': amount, 'p_day': day}));

  @override
  Future<List<RemoteExpense>> expensesSince(String? since) => _guard(() async {
        var q = _client.from('expenses').select('*, expense_shares(user_id, share)');
        if (since != null) q = q.gt('updated_at', since);
        final rows = await q.order('updated_at').limit(500);
        return [
          for (final r in rows)
            RemoteExpense(
              id: r['id'] as String,
              createdBy: r['created_by'] as String,
              title: r['title'] as String,
              total: r['total'] as int,
              payer: r['payer'] as String,
              day: r['day'] as String,
              deleted: r['deleted'] as bool,
              shares: {for (final s in (r['expense_shares'] as List).cast<Map>()) s['user_id'] as String: s['share'] as int},
              updatedAt: r['updated_at'] as String,
            ),
        ];
      });

  @override
  Future<List<RemotePayment>> paymentsSince(String? since) => _guard(() async {
        var q = _client.from('payments').select();
        if (since != null) q = q.gt('updated_at', since);
        final rows = await q.order('updated_at').limit(500);
        return [
          for (final r in rows)
            RemotePayment(
              id: r['id'] as String,
              from: r['from_user'] as String,
              to: r['to_user'] as String,
              amount: r['amount'] as int,
              day: r['day'] as String,
              createdBy: r['created_by'] as String,
              deleted: r['deleted'] as bool,
              updatedAt: r['updated_at'] as String,
            ),
        ];
      });

  @override
  Future<void> saveBackup(List<BackupRow> rows) => _guard(() async {
        final owner = _client.auth.currentUser!.id;
        await _client.from('backup_rows').upsert(
          [for (final r in rows) {'owner': owner, 'kind': r.kind, 'key': r.key, 'data': r.data}],
          onConflict: 'owner,kind,key',
        );
      });

  @override
  Future<List<BackupRow>> loadBackup() => _guard(() async {
        const page = 1000;
        final out = <BackupRow>[];
        for (var from = 0;; from += page) {
          final rows = await _client.from('backup_rows').select('kind, key, data').order('kind').order('key').range(from, from + page - 1);
          out.addAll([for (final r in rows) BackupRow(r['kind'] as String, r['key'] as String, (r['data'] as Map).cast<String, Object?>())]);
          if (rows.length < page) return out;
        }
      });
}
