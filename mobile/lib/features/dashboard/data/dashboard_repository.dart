import '../domain/dashboard_filters.dart';
import '../domain/dashboard_stats.dart';
import '../../../data/ironsource/ironsource_api_client.dart';

class DashboardRepository {
  DashboardRepository({IronSourceApiClient? apiClient})
      : _api = apiClient ?? IronSourceApiClient();

  final IronSourceApiClient _api;

  static double _n(Map<String, dynamic> d, String k) =>
      (d[k] is num) ? (d[k] as num).toDouble() : 0;

  /// Agregación sin redondeos intermedios. Solo redondear al mostrar.
  static DashboardStats statsFromRows(List<IronSourceStatsRow> rows) {
    double revenue = 0, fillRateSum = 0, completionRateSum = 0, revPerCompSum = 0, ctrSum = 0;
    int impressions = 0, clicks = 0, completions = 0, appRequests = 0, dau = 0, sessions = 0;
    int fillRateCount = 0, completionRateCount = 0, revPerCompCount = 0, ctrCount = 0;
    for (final row in rows) {
      for (final d in row.data ?? []) {
        revenue += _n(d, 'revenue');
        impressions += _n(d, 'impressions').toInt();
        clicks += _n(d, 'clicks').toInt();
        completions += _n(d, 'completions').toInt();
        appRequests += _n(d, 'appRequests').toInt();
        dau += _n(d, 'dau').toInt();
        sessions += _n(d, 'sessions').toInt();
        final fr = _n(d, 'appFillRate');
        if (fr > 0) { fillRateSum += fr; fillRateCount++; }
        final cr = _n(d, 'completionRate');
        if (cr > 0) { completionRateSum += cr; completionRateCount++; }
        final rpc = _n(d, 'revenuePerCompletion');
        if (rpc > 0) { revPerCompSum += rpc; revPerCompCount++; }
        final ctr = _n(d, 'clickThroughRate');
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

  /// Stats del periodo anterior (misma duración, días previos) para comparar %.
  Future<DashboardStats?> getPreviousPeriodStats(DashboardFilters filters) async {
    final days = filters.endDate.difference(filters.startDate).inDays + 1;
    final prevEnd = filters.startDate.subtract(const Duration(days: 1));
    final prevStart = prevEnd.subtract(Duration(days: days - 1));
    final prevFilters = DashboardFilters(
      startDate: prevStart,
      endDate: prevEnd,
      datePreset: filters.datePreset,
      appKeys: filters.appKeys,
      platforms: filters.platforms,
      adUnits: filters.adUnits,
      countries: filters.countries,
    );
    try {
      final rows = await getStatsRaw(prevFilters);
      return statsFromRows(rows);
    } catch (_) {
      return null;
    }
  }

  /// Obtiene stats. Con breakdowns: 'date' + filtros vía API los totales coinciden con IronSource.
  Future<List<IronSourceStatsRow>> getStatsRaw(DashboardFilters filters) async {
    final appKey = _join(filters.appKeys);
    final country = _join(filters.countries);
    final adUnits = _mapAdFormatForApi(_join(filters.adUnits));
    final platform = _platformParam(filters.platforms);
    return _api.getStats(
      startDate: filters.startDateStr,
      endDate: filters.endDateStr,
      appKey: appKey,
      country: country,
      adUnits: adUnits,
      platform: platform,
      breakdowns: 'date',
      metrics: null,
    );
  }

  /// Llamada con breakdowns completos solo para obtener dimensiones (países, etc).
  /// No usar para stats (hay drift por redondeo). Solo para opciones de filtros.
  Future<List<IronSourceStatsRow>> getFilterMetadata(DashboardFilters filters) async {
    return _api.getStats(
      startDate: filters.startDateStr,
      endDate: filters.endDateStr,
      appKey: null,
      country: null,
      adUnits: null,
      platform: null,
      breakdowns: 'date,adFormat,platform,country,app',
      metrics: 'revenue,impressions',
    );
  }

  static String? _mapAdFormatForApi(String? adFormatCsv) {
    if (adFormatCsv == null || adFormatCsv.isEmpty) return null;
    final mapped = adFormatCsv.split(',').map((s) {
      final t = s.trim().toLowerCase();
      if (t == 'rewardedvideo') return 'rewarded';
      if (t == 'offerwall') return 'offerwall';
      if (t == 'interstitial') return 'interstitial';
      if (t == 'banner') return 'banner';
      return s.trim();
    }).where((s) => s.isNotEmpty).toList();
    return mapped.isEmpty ? null : mapped.join(',');
  }

  static String? _join(List<String>? list) {
    if (list == null || list.isEmpty) return null;
    return list.join(',');
  }

  static String? _platformParam(List<String>? platforms) {
    if (platforms == null || platforms.isEmpty) return null;
    if (platforms.length == 2) return null;
    return platforms.single.toLowerCase();
  }

  Future<List<IronSourceApp>> getApplications() async {
    return _api.getApplications();
  }

  /// Valida que las credenciales guardadas funcionen (puede hacer una llamada ligera).
  Future<bool> validateCredentials() async {
    try {
      await _api.getApplications();
      return true;
    } catch (_) {
      return false;
    }
  }
}
