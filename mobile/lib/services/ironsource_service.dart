import '../models/dashboard_stats.dart';

class IronSourceService {
  Future<DashboardStats> fetchDashboardData() async {
    await Future.delayed(const Duration(seconds: 1));

    return DashboardStats(
      revenue: 123.45,
      impressions: 12340,
      ecpm: 9.87,
    );
  }
}