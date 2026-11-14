import 'package:flutter/widgets.dart';

import 'data/auth.dart';
import 'data/remote.dart';
import 'data/store.dart';
import 'data/sync.dart';

/// The one piece of app state: the store plus "something changed".
/// Screens read through [StubScope.of] and rebuild after every [write].
class AppModel extends ChangeNotifier {
  AppModel(this.store, {DateTime Function()? clock, Auth? auth, this.remoteFor})
      : _clock = clock ?? DateTime.now,
        auth = auth ?? OfflineAuth() {
    store.runAutopays(today);
    this.auth.addListener(_authChanged);
    _authChanged();
  }

  /// Makes the online connection for a signed-in account; null when the app
  /// runs without the online service.
  final Remote Function(String userId)? remoteFor;

  /// Present while signed in with a profile; keeps friends in step online.
  Sync? sync;

  void _authChanged() {
    final account = auth.account;
    final ready = account != null && !account.needsProfile && remoteFor != null;
    if (ready && sync?.me != account.id) {
      sync?.dispose();
      sync = Sync(store: store, remote: remoteFor!(account.id), me: account.id, onChanged: notifyListeners)
        ..addListener(notifyListeners);
      sync!.run();
    } else if (!ready && sync != null) {
      sync!.dispose();
      sync = null;
    }
    notifyListeners();
  }

  final StubStore store;

  /// Optional sign-in, only needed for splitting with friends online.
  final Auth auth;
  final DateTime Function() _clock;

  DateTime get now => _clock();

  /// Today with the time stripped.
  DateTime get today {
    final now = _clock();
    return DateTime(now.year, now.month, now.day);
  }

  /// Runs a change against the store and tells every screen to refresh.
  @override
  void dispose() {
    auth.removeListener(_authChanged);
    sync?.dispose();
    super.dispose();
  }

  T write<T>(T Function(StubStore store) change) {
    final result = change(store);
    notifyListeners();
    sync?.run();
    return result;
  }
}

class StubScope extends InheritedNotifier<AppModel> {
  const StubScope({super.key, required AppModel model, required super.child})
      : super(notifier: model);

  static AppModel of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<StubScope>()!.notifier!;
  }
}
