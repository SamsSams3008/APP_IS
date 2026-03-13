import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';
import '../../core/error_utils.dart';
import '../../core/iap/iap_service.dart';
import '../../core/subscription/subscription_notifier.dart';
import '../../../data/credentials/credentials_repository.dart';
import '../dashboard/data/dashboard_repository.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _resolveRoute());
  }

  Future<void> _resolveRoute() async {
    await SubscriptionNotifier.load();
    await IapService.init();
    // Reset credenciales una sola vez (onboarding v2)
    final prefs = await SharedPreferences.getInstance();
    final resetDone = prefs.getBool(AppConstants.storageOnboardingV2Reset);
    if (resetDone != true) {
      await CredentialsRepository().clearAll();
      await prefs.setBool(AppConstants.storageOnboardingV2Reset, true);
    }
    final hasCredentials = await CredentialsRepository().hasCredentials();
    if (!mounted) return;
    if (!hasCredentials) {
      context.go('/welcome');
      return;
    }
    final (valid, error) = await DashboardRepository().validateCredentialsWithError();
    if (!mounted) return;
    if (valid) {
      context.go('/dashboard');
      return;
    }
    // Si es error de red: ir al dashboard para que muestre "sin internet" y pueda reintentar
    if (ErrorUtils.isNetworkError(error ?? '')) {
      context.go('/dashboard');
      return;
    }
    if (ErrorUtils.isKeysError(error)) {
      context.go('/credentials');
      return;
    }
    context.go('/dashboard'); // otros errores: intentar en dashboard
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.black,
        child: Center(
          child: Image.asset(
            'assets/icon/logo.png',
            height: 200,
            width: 200,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => Icon(
              LucideIcons.barChart2,
              size: 96,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      ),
    );
  }
}
