import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
    final hasCredentials = await CredentialsRepository().hasCredentials();
    if (!mounted) return;
    if (!hasCredentials) {
      context.go('/credentials');
      return;
    }
    final valid = await DashboardRepository().validateCredentials();
    if (!mounted) return;
    if (valid) {
      context.go('/dashboard');
    } else {
      context.go('/credentials');
    }
  }

  static const Color _splashBg = Color(0xFF000000);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _splashBg,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: _splashBg,
        child: Center(
          child: Image.asset(
            'assets/icon/logo.png',
            height: 200,
            width: 200,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => Icon(
              Icons.analytics_outlined,
              size: 96,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      ),
    );
  }
}
