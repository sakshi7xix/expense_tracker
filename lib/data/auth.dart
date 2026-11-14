import 'package:flutter/foundation.dart';

/// The signed-in person, if any.
class Account {
  const Account({required this.id, required this.email, this.name});

  final String id;
  final String email;

  /// Null until the "About you" step is done.
  final String? name;

  bool get needsProfile => name == null;
}

/// Something went wrong signing in; [message] is fit to show as it is.
class AuthFailure implements Exception {
  const AuthFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Signing in with an emailed 6-digit code. Signing in is optional: the app
/// works fully without it, and only splits with friends need an account.
abstract class Auth extends ChangeNotifier {
  /// False when the app was started without the online service.
  bool get available;

  Account? get account;

  Future<void> sendCode(String email);

  /// Checks the emailed code and signs in. Throws [AuthFailure] if wrong.
  Future<void> verifyCode(String email, String code);

  /// Saves the name, and records that the person confirmed they are 18 or over.
  Future<void> saveProfile(String name);

  Future<void> signOut();

  /// Removes the account and its online data for good.
  Future<void> deleteAccount();
}

/// Used when there is no online service (tests, or no connection set up).
class OfflineAuth extends Auth {
  @override
  bool get available => false;

  @override
  Account? get account => null;

  Never _no() => throw const AuthFailure('Signing in is not available right now.');

  @override
  Future<void> sendCode(String email) async => _no();

  @override
  Future<void> verifyCode(String email, String code) async => _no();

  @override
  Future<void> saveProfile(String name) async => _no();

  @override
  Future<void> signOut() async {}

  @override
  Future<void> deleteAccount() async => _no();
}

/// Checks an email address well enough to catch typos before sending a code.
bool looksLikeEmail(String text) {
  return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$').hasMatch(text.trim());
}

/// A name for the profile: trimmed, 1 to 60 characters.
String? cleanName(String text) {
  final name = text.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (name.isEmpty || name.length > 60) return null;
  return name;
}
