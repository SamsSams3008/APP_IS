/// Aggregated stats for the dashboard.
class DashboardStats {
  const DashboardStats({
    required this.revenue,
    required this.impressions,
    required this.ecpm,
    this.clicks,
    this.completions,
  });

  final double revenue;
  final int impressions;
  final double ecpm;
  final int? clicks;
  final int? completions;
}
