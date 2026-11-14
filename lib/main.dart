import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'app_model.dart';
import 'core/config.dart';
import 'data/auth.dart';
import 'data/db.dart';
import 'data/store.dart';
import 'data/supabase_auth.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _registerFontLicences();
  final dir = await getApplicationDocumentsDirectory();
  final store = StubStore(openFileDb(p.join(dir.path, 'stub.db')));
  runApp(StubApp(model: AppModel(store, auth: await _connect())));
}

/// Signing in is optional, so if the online service can't start the app
/// still opens and works on this phone alone.
Future<Auth> _connect() async {
  try {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.publishableKey,
      authOptions: const FlutterAuthClientOptions(localStorage: SecureSessionStorage()),
    );
    return SupabaseAuth(Supabase.instance.client);
  } catch (_) {
    return OfflineAuth();
  }
}

/// The bundled fonts' licences (SIL Open Font License), shown in Settings →
/// Licences next to every package's own licence.
void _registerFontLicences() {
  LicenseRegistry.addLicense(() async* {
    for (final (family, file) in [('Nunito', 'OFL-Nunito.txt'), ('IBM Plex Mono', 'OFL-IBMPlexMono.txt')]) {
      final text = await rootBundle.loadString('assets/fonts/$file');
      yield LicenseEntryWithLineBreaks([family], text);
    }
  });
}
