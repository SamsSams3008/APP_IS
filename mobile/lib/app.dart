import 'package:flutter/material.dart';

import 'core/locale_notifier.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode_notifier.dart';

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  @override
  void initState() {
    super.initState();
    ThemeModeNotifier.valueNotifier.addListener(_onThemeChanged);
    LocaleNotifier.valueNotifier.addListener(_onLocaleChanged);
  }

  @override
  void dispose() {
    LocaleNotifier.valueNotifier.removeListener(_onLocaleChanged);
    ThemeModeNotifier.valueNotifier.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() => setState(() {});
  void _onLocaleChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Ad Revenue Dashboard - For ironSource',
      debugShowCheckedModeBanner: false,
      locale: LocaleNotifier.locale,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeModeNotifier.valueNotifier.value,
      routerConfig: AppRouter.createRouter(),
    );
  }
}
