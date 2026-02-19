import 'package:flutter/material.dart';

import 'app.dart';
import 'core/locale_notifier.dart';
import 'core/theme/theme_mode_notifier.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ThemeModeNotifier.load();
  await LocaleNotifier.load();
  runApp(const App());
}
