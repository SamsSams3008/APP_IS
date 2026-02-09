import '../domain/dashboard_stats.dart';
import '../../../data/ironsource/ironsource_api_client.dart';

class DashboardRepository {
  DashboardRepository({IronSourceApiClient? apiClient})
      : _api = apiClient ?? IronSourceApiClient();

  final IronSourceApiClient _api;

  /// Calcula estadísticas agregadas a partir de filas crudas (para usar con datos cacheados).
  static DashboardStats statsFromRows(List<IronSourceStatsRow> rows) {
    double revenue = 0;
    int impressions = 0;
    int clicks = 0;
    int completions = 0;
    for (final row in rows) {
      for (final d in row.data ?? []) {
        revenue += (d['revenue'] is num) ? (d['revenue'] as num).toDouble() : 0;
        impressions += (d['impressions'] is num) ? (d['impressions'] as num).toInt() : 0;
        clicks += (d['clicks'] is num) ? (d['clicks'] as num).toInt() : 0;
        completions += (d['completions'] is num) ? (d['completions'] as num).toInt() : 0;
      }
    }
    final ecpm = impressions > 0 ? (revenue / impressions) * 1000 : 0.0;
    return DashboardStats(
      revenue: revenue,
      impressions: impressions,
      ecpm: ecpm,
      clicks: clicks,
      completions: completions,
    );
  }

  /// Pide todos los datos del rango de fechas en una sola llamada (sin filtrar por app/adUnit/país).
  /// Así se puede cachear y filtrar en memoria al cambiar filtros.
  Future<List<IronSourceStatsRow>> getStatsRawFull(String startDate, String endDate) async {
    return _api.getStats(
      startDate: startDate,
      endDate: endDate,
      appKey: null,
      country: null,
      adUnits: null,
      breakdowns: 'date,adUnits,appKey,country',
      metrics: 'revenue,impressions,eCPM,clicks,completions',
    );
  }

  Future<List<IronSourceApp>> getApplications() async {
    return _api.getApplications();
  }
}
