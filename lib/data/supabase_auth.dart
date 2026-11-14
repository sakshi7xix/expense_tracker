import 'dart:async';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth.dart';

/// [Auth] backed by Supabase: email one-time codes, and the `profiles` table
/// (readable and writable only by its owner, see supabase/migrations).
class SupabaseAuth extends Auth {
  SupabaseAuth(this._client) {
    _sub = _client.auth.onAuthStateChange.listen((_) => _load());
    _load();
  }

  final SupabaseClient _client;
  late final StreamSubscription<AuthState> _sub;
  Account? _account;

  @override
  bool get available => true;

  @override
  Account? get account => _account;

  Future<void> _load() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      _set(null);
      return;
    }
    // Show the account straight away, then fill in the name.
    _account ??= Account(id: user.id, email: user.email ?? '');
    try {
      final row = await _client.from('profiles').select('name').eq('id', user.id).maybeSingle();
      _set(Account(id: user.id, email: user.email ?? '', name: row?['name'] as String?));
    } catch (_) {
      // Offline: keep what we had.
      notifyListeners();
    }
  }

  void _set(Account? account) {
    _account = account;
    notifyListeners();
  }

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on AuthRetryableFetchException {
      throw const AuthFailure('No internet connection. Try again when you are online.');
    } on AuthException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('expired') || msg.contains('invalid') || msg.contains('token')) {
        throw const AuthFailure('That code is wrong or has expired. Check it, or send a new one.');
      }
      if (e.statusCode == '429' || msg.contains('rate')) {
        throw const AuthFailure('Too many tries. Wait a minute and try again.');
      }
      throw AuthFailure(e.message);
    } on SocketException {
      throw const AuthFailure('No internet connection. Try again when you are online.');
    } on PostgrestException {
      throw const AuthFailure('Something went wrong saving that. Try again.');
    }
  }

  @override
  Future<void> sendCode(String email) {
    return _guard(() => _client.auth.signInWithOtp(email: email.trim().toLowerCase(), shouldCreateUser: true));
  }

  @override
  Future<void> verifyCode(String email, String code) async {
    await _guard(
      () => _client.auth.verifyOTP(type: OtpType.email, email: email.trim().toLowerCase(), token: code.trim()),
    );
    await _load();
  }

  @override
  Future<void> saveProfile(String name) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const AuthFailure('Sign in first.');
    await _guard(() async {
      if (_account?.name == null) {
        await _client.from('profiles').insert({
          'id': user.id,
          'name': name,
          'adult_confirmed_at': DateTime.now().toUtc().toIso8601String(),
        });
      } else {
        await _client.from('profiles').update({
          'name': name,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }).eq('id', user.id);
      }
    });
    _set(Account(id: user.id, email: user.email ?? '', name: name));
  }

  @override
  Future<void> signOut() async {
    await _client.auth.signOut();
    _set(null);
  }

  @override
  Future<void> deleteAccount() async {
    await _guard(() => _client.rpc('delete_account'));
    await _client.auth.signOut(scope: SignOutScope.local);
    _set(null);
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

/// Keeps the sign-in session in the Keychain (iOS) or Keystore-backed
/// storage (Android) rather than plain app preferences.
class SecureSessionStorage extends LocalStorage {
  const SecureSessionStorage();

  static const _key = 'session';
  static const _storage = FlutterSecureStorage();

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> hasAccessToken() => _storage.containsKey(key: _key);

  @override
  Future<String?> accessToken() => _storage.read(key: _key);

  @override
  Future<void> persistSession(String persistSessionString) {
    return _storage.write(key: _key, value: persistSessionString);
  }

  @override
  Future<void> removePersistedSession() => _storage.delete(key: _key);
}
