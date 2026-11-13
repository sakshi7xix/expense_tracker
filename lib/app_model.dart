import 'package:flutter/widgets.dart';

import 'data/store.dart';

/// The one piece of app state: the store plus "something changed".
/// Screens read through [StubScope.of] and rebuild after every [write].
class AppModel extends ChangeNotifier {
  AppModel(this.store, {DateTime Function()? clock}) : _clock = clock ?? DateTime.now {
    store.runAutopays(today);
  }

  final StubStore store;
  final DateTime Function() _clock;

  /// Today with the time stripped.
  DateTime get today {
    final now = _clock();
    return DateTime(now.year, now.month, now.day);
  }

  /// Runs a change against the store and tells every screen to refresh.
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
