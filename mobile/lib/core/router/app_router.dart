import 'package:go_router/go_router.dart';

import '../../features/credentials/presentation/screens/credentials_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/dashboard/presentation/screens/metric_detail_screen.dart';
import '../../features/glossary/glossary_screen.dart';
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
          path: '/glossary',
          builder: (context, state) => const GlossaryScreen(),
        ),
        GoRoute(
          path: '/dashboard',
          builder: (context, state) => const DashboardScreen(),
        ),
        GoRoute(
          path: '/dashboard/metric/:metricId',
          builder: (context, state) {
            final metricId = state.pathParameters['metricId'] ?? 'revenue';
            return MetricDetailScreen(metricId: metricId);
          },
        ),
      ],
    );
  }
}
