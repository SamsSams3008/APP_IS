import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../features/dashboard/domain/dashboard_stats.dart';

/// Fila de estadísticas devuelta por el backend (Firestore vía Cloud Functions).
class BackendStatsRow {
  BackendStatsRow({
    this.date,
    this.adUnits,
    this.appKey,
    this.country,
    this.platform,
    this.revenue = 0,
    this.impressions = 0,
    this.eCPM = 0,
    this.clicks = 0,
    this.completions = 0,
  });

  final String? date;
  final String? adUnits;
  final String? appKey;
  final String? country;
  final String? platform;
  final double revenue;
  final int impressions;
  final double eCPM;
  final int clicks;
  final int completions;

  static BackendStatsRow fromMap(Map<String, dynamic> m) {
    return BackendStatsRow(
      date: m['date'] as String?,
      adUnits: m['adUnits'] as String?,
      appKey: m['appKey'] as String?,
      country: m['country'] as String?,
      platform: m['platform'] as String?,
      revenue: (m['revenue'] is num) ? (m['revenue'] as num).toDouble() : 0,
      impressions: (m['impressions'] is num) ? (m['impressions'] as num).toInt() : 0,
      eCPM: (m['eCPM'] is num) ? (m['eCPM'] as num).toDouble() : 0,
      clicks: (m['clicks'] is num) ? (m['clicks'] as num).toInt() : 0,
      completions: (m['completions'] is num) ? (m['completions'] as num).toInt() : 0,
    );
  }
}

class BackendStatsResult {
  BackendStatsResult({
    required this.stats,
    required this.chartData,
    required this.tableRows,
  });

  final DashboardStats stats;
  final List<ChartPoint> chartData;
  final List<BackendStatsRow> tableRows;
}

class ChartPoint {
  ChartPoint({required this.date, required this.value});
  final String date;
  final double value;
}

class BackendApp {
  BackendApp({this.appKey, this.appName, this.platform, this.bundleId});
  final String? appKey;
  final String? appName;
  final String? platform;
  final String? bundleId;
}

/// Obtiene estadísticas y lista de apps desde el backend (datos ya sincronizados por el cron).
class BackendStatsRepository {
  BackendStatsRepository({
    FirebaseFunctions? functions,
    FirebaseAuth? auth,
  })  : _functions = functions ?? FirebaseFunctions.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFunctions _functions;
  final FirebaseAuth _auth;

  /// Lista de aplicaciones IronSource del usuario (para filtro por app).
  Future<List<BackendApp>> getApplications() async {
    if (_auth.currentUser == null) return [];
    try {
      final callable = _functions.httpsCallable('getApplications');
      final result = await callable.call();
      final list = result.data as List<dynamic>? ?? [];
      return list
          .map((e) => BackendApp(
                appKey: (e as Map)['appKey'] as String?,
                appName: (e['appName'] as String?),
                platform: (e['platform'] as String?),
                bundleId: (e['bundleId'] as String?),
              ))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Pide al backend que sincronice ahora los datos de IronSource para el usuario actual.
  Future<void> requestSync() async {
    if (_auth.currentUser == null) return;
    final callable = _functions.httpsCallable('requestSync');
    await callable.call();
  }

  /// Obtiene estadísticas del backend para el rango de fechas (y opcionalmente filtros).
  Future<BackendStatsResult> getStats({
    required String startDate,
    required String endDate,
    String? appKey,
    String? adUnits,
    String? country,
    String? platform,
  }) async {
    if (_auth.currentUser == null) {
      throw Exception('Debes iniciar sesión.');
    }
    final callable = _functions.httpsCallable('getStats');
    final result = await callable.call(<String, dynamic>{
      'startDate': startDate,
      'endDate': endDate,
      if (appKey != null && appKey.isNotEmpty) 'appKey': appKey,
      if (adUnits != null && adUnits.isNotEmpty) 'adUnits': adUnits,
      if (country != null && country.isNotEmpty) 'country': country,
      if (platform != null && platform.isNotEmpty) 'platform': platform,
    });

    final data = result.data as Map<String, dynamic>?;
    if (data == null) throw Exception('Respuesta vacía del backend.');

    final statsMap = data['stats'] as Map<String, dynamic>? ?? {};
    final stats = DashboardStats(
      revenue: (statsMap['revenue'] is num) ? (statsMap['revenue'] as num).toDouble() : 0,
      impressions: (statsMap['impressions'] is num) ? (statsMap['impressions'] as num).toInt() : 0,
      ecpm: (statsMap['ecpm'] is num) ? (statsMap['ecpm'] as num).toDouble() : 0,
      clicks: (statsMap['clicks'] is num) ? (statsMap['clicks'] as num).toInt() : 0,
      completions: (statsMap['completions'] is num) ? (statsMap['completions'] as num).toInt() : 0,
    );

    final chartList = data['chartData'] as List<dynamic>? ?? [];
    final chartData = chartList
        .map((e) => ChartPoint(
              date: (e as Map)['date'] as String? ?? '',
              value: (e['value'] is num) ? (e['value'] as num).toDouble() : 0,
            ))
        .toList();

    final tableList = data['tableRows'] as List<dynamic>? ?? [];
    final tableRows = tableList
        .map((e) => BackendStatsRow.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();

    return BackendStatsResult(stats: stats, chartData: chartData, tableRows: tableRows);
  }

  /// Calcula estadísticas agregadas a partir de filas (para filtrar en memoria).
  static DashboardStats statsFromRows(List<BackendStatsRow> rows) {
    double revenue = 0;
    int impressions = 0;
    int clicks = 0;
    int completions = 0;
    for (final r in rows) {
      revenue += r.revenue;
      impressions += r.impressions;
      clicks += r.clicks;
      completions += r.completions;
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
}
