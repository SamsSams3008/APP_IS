/// Aggregated stats for the dashboard (métricas IronSource).
class DashboardStats {
  const DashboardStats({
    required this.revenue,
    required this.impressions,
    required this.ecpm,
    this.clicks,
    this.completions,
    this.completionRate,
    this.fillRate,
    this.revenuePerCompletion,
    this.ctr,
    this.appRequests,
    this.dau,
    this.sessions,
  });

  final double revenue;
  final int impressions;
  final double ecpm;
  final int? clicks;
  final int? completions;
  final double? completionRate;
  final double? fillRate;
  final double? revenuePerCompletion;
  final double? ctr;
  final int? appRequests;
  /// Daily Active Users (si la API lo devuelve).
  final int? dau;
  /// Sesiones (si la API lo devuelve).
  final int? sessions;
}
