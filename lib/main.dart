import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'app_model.dart';
import 'data/db.dart';
import 'data/store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final dir = await getApplicationDocumentsDirectory();
  final store = StubStore(openFileDb(p.join(dir.path, 'stub.db')));
  runApp(StubApp(model: AppModel(store)));
}
