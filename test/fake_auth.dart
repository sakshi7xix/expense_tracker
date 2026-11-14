import 'package:stub/data/auth.dart';

/// Sign-in without a server: the code is always 123456.
class FakeAuth extends Auth {
  FakeAuth({Account? signedIn}) : _account = signedIn;

  Account? _account;
  String? sentTo;
  bool deleted = false;
  final names = <String, String>{};

  @override
  bool get available => true;

  @override
  Account? get account => _account;

  @override
  Future<void> sendCode(String email) async => sentTo = email.trim();

  @override
  Future<void> verifyCode(String email, String code) async {
    if (code != '123456') throw const AuthFailure('That code is wrong or has expired. Check it, or send a new one.');
    final e = email.trim();
    _account = Account(id: 'user-$e', email: e, name: names[e]);
    notifyListeners();
  }

  @override
  Future<void> saveProfile(String name) async {
    final a = _account!;
    names[a.email] = name;
    _account = Account(id: a.id, email: a.email, name: name);
    notifyListeners();
  }

  @override
  Future<void> signOut() async {
    _account = null;
    notifyListeners();
  }

  @override
  Future<void> deleteAccount() async {
    deleted = true;
    _account = null;
    notifyListeners();
  }
}
