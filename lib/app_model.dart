import 'package:flutter/widgets.dart';

import 'data/auth.dart';
import 'data/store.dart';

/// The one piece of app state: the store plus "something changed".
/// Screens read through [StubScope.of] and rebuild after every [write].
class AppModel extends ChangeNotifier {
  AppModel(this.store, {DateTime Function()? clock, Auth? auth})
      : _clock = clock ?? DateTime.now,
        auth = auth ?? OfflineAuth() {
    store.runAutopays(today);
    this.auth.addListener(notifyListeners);
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
    auth.removeListener(notifyListeners);
    super.dispose();
  }

  T write<T>(T Function(StubStore store) change) {
    final result = change(store);
    notifyListeners();
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
