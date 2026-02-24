import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
  final ValueNotifier<bool> _transitionNotifier = ValueNotifier(false);
  late final GoRouter _router = AppRouter.createRouter();

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
    _transitionNotifier.dispose();
    super.dispose();
  }

  void _onThemeChanged() {
    setState(() {});
  }

  void _onLocaleChanged() {
    _transitionNotifier.value = true;
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _transitionNotifier.value = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Ad Revenue Dashboard - For ironSource',
      debugShowCheckedModeBanner: false,
      locale: LocaleNotifier.locale,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeModeNotifier.valueNotifier.value,
      themeAnimationDuration: const Duration(milliseconds: 200),
      routerConfig: _router,
      builder: (context, child) {
        return Stack(
          children: [
            child ?? const SizedBox.shrink(),
            ValueListenableBuilder<bool>(
              valueListenable: _transitionNotifier,
              builder: (_, transitioning, __) {
                if (!transitioning) return const SizedBox.shrink();
                return _ThemeLocaleLoadingOverlay();
              },
            ),
          ],
        );
      },
    );
  }
}

class _ThemeLocaleLoadingOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: Center(
        child: CircularProgressIndicator(
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
