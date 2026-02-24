import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'core/locale_notifier.dart';
import 'core/theme/theme_mode_notifier.dart';
import 'features/dashboard/domain/dashboard_filters.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  await ThemeModeNotifier.load();
  await LocaleNotifier.load();
  // No persistir filtros al salir: cada vez que se abre la app se resetean.
  await DashboardFilters.saveDashboard(DashboardFilters.last7Days());
  runApp(const App());
}
