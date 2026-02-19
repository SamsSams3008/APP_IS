import '../domain/dashboard_stats.dart';
import '../../../data/ironsource/ironsource_api_client.dart';

class DashboardRepository {
  DashboardRepository({IronSourceApiClient? apiClient})
      : _api = apiClient ?? IronSourceApiClient();

  final IronSourceApiClient _api;

  static double _num(Map<String, dynamic> d, String k) =>
      (d[k] is num) ? (d[k] as num).toDouble() : 0;

  /// Calcula estadísticas agregadas a partir de filas crudas.
  static DashboardStats statsFromRows(List<IronSourceStatsRow> rows) {
    double revenue = 0;
    int impressions = 0;
    int clicks = 0;
    int completions = 0;
    double fillRateSum = 0;
    int fillRateCount = 0;
    double completionRateSum = 0;
    int completionRateCount = 0;
    double revPerCompSum = 0;
    int revPerCompCount = 0;
    double ctrSum = 0;
    int ctrCount = 0;
    int appRequests = 0;
    int dau = 0;
    int sessions = 0;
    for (final row in rows) {
      for (final d in row.data ?? []) {
        revenue += _num(d, 'revenue');
        impressions += _num(d, 'impressions').toInt();
        clicks += _num(d, 'clicks').toInt();
        completions += _num(d, 'completions').toInt();
        appRequests += _num(d, 'appRequests').toInt();
        dau += _num(d, 'dau').toInt();
        sessions += _num(d, 'sessions').toInt();
        final fr = _num(d, 'appFillRate');
        if (fr > 0) { fillRateSum += fr; fillRateCount++; }
        final cr = _num(d, 'completionRate');
        if (cr > 0) { completionRateSum += cr; completionRateCount++; }
        final rpc = _num(d, 'revenuePerCompletion');
        if (rpc > 0) { revPerCompSum += rpc; revPerCompCount++; }
        final ctr = _num(d, 'clickThroughRate');
        if (ctr > 0) { ctrSum += ctr; ctrCount++; }
      }
    }
    final ecpm = impressions > 0 ? (revenue / impressions) * 1000 : 0.0;
    return DashboardStats(
      revenue: revenue,
      impressions: impressions,
      ecpm: ecpm,
      clicks: clicks,
      completions: completions,
      completionRate: completionRateCount > 0 ? completionRateSum / completionRateCount : (impressions > 0 && completions > 0 ? (completions / impressions) * 100 : null),
      fillRate: fillRateCount > 0 ? fillRateSum / fillRateCount : null,
      revenuePerCompletion: revPerCompCount > 0 ? revPerCompSum / revPerCompCount : (completions > 0 ? revenue / completions : null),
      ctr: ctrCount > 0 ? ctrSum / ctrCount : (impressions > 0 && clicks > 0 ? (clicks / impressions) * 100 : null),
      appRequests: appRequests > 0 ? appRequests : null,
      dau: dau > 0 ? dau : null,
      sessions: sessions > 0 ? sessions : null,
    );
  }

  /// Pide todos los datos del rango de fechas (máximas métricas y breakdowns para filtrar en memoria).
  Future<List<IronSourceStatsRow>> getStatsRawFull(String startDate, String endDate) async {
    return _api.getStats(
      startDate: startDate,
      endDate: endDate,
      appKey: null,
      country: null,
      adUnits: null,
      breakdowns: 'date,adFormat,platform,country,app',
      metrics: 'revenue,impressions,eCPM,clicks,completions,appFillRate,completionRate,revenuePerCompletion,clickThroughRate,appRequests,activeUsers,sessions',
    );
  }

  Future<List<IronSourceApp>> getApplications() async {
    return _api.getApplications();
  }
}
