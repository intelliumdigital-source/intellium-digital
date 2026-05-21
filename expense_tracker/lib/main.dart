import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

export 'app/legacy_app.dart' hide main;

import 'app/legacy_app.dart' as legacy;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  legacy.main();
}
