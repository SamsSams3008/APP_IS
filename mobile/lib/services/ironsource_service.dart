import '../models/dashboard_stats.dart';
import '../models/revenue_point.dart';

class IronSourceService {
  Future<DashboardStats> fetchDashboardData() async {
    await Future.delayed(const Duration(seconds: 1));

    return DashboardStats(
      revenue: 123.45,
      impressions: 12340,
      ecpm: 9.87,
    );
  }

  List<RevenuePoint> getRevenueChartData() {
    return [
      RevenuePoint(1, 12),
      RevenuePoint(2, 18),
      RevenuePoint(3, 9),
      RevenuePoint(4, 22),
      RevenuePoint(5, 17),
      RevenuePoint(6, 30),
      RevenuePoint(7, 25),
    ];
  }
}