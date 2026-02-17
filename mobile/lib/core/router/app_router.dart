import 'package:go_router/go_router.dart';

import '../../features/credentials/presentation/screens/credentials_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/splash/splash_screen.dart';

class AppRouter {
  static GoRouter createRouter() {
    return GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const SplashScreen(),
        ),
        GoRoute(
          path: '/credentials',
          builder: (context, state) => const CredentialsScreen(),
        ),
        GoRoute(
          path: '/dashboard',
          builder: (context, state) => const DashboardScreen(),
        ),
      ],
    );
  }
}
