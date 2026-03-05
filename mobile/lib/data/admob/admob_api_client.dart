import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/config/admob_oauth_credentials.dart';
import '../credentials/credentials_repository.dart';
import '../ironsource/ironsource_api_client.dart';
import 'admob_oauth.dart';

/// AdMob API client using OAuth2 refresh token.
class AdMobApiClient {
  AdMobApiClient({
    CredentialsRepository? credentialsRepository,
  }) : _credentials = credentialsRepository ?? CredentialsRepository();

  final CredentialsRepository _credentials;

  static const _accountsUrl = 'https://admob.googleapis.com/v1/accounts';

  Future<String?> _getAccessToken() async {
    final clientId = kAdMobOAuthClientId.trim();
    final clientSecret = kAdMobOAuthClientSecret.trim();
    final refreshToken = await _credentials.getAdMobRefreshToken();
    if (clientId.isEmpty ||
        refreshToken == null ||
        refreshToken.isEmpty) {
      return null;
    }
    return AdMobOAuth.refreshAccessToken(
      clientId: clientId,
      refreshToken: refreshToken,
      clientSecret: clientSecret.isEmpty ? null : clientSecret,
    );
  }

  /// Lista de apps del cuenta AdMob (accounts.apps.list). Compatible con IronSourceApp para el filtro.
  Future<List<IronSourceApp>> getApps() async {
    final publisherId = await _credentials.getAdMobPublisherId();
    if (publisherId == null || publisherId.isEmpty) return [];

    final accessToken = await _getAccessToken();
    if (accessToken == null || accessToken.isEmpty) return [];

    final accountName = publisherId.startsWith('pub-')
        ? 'accounts/$publisherId'
        : 'accounts/pub-$publisherId';
    final url = 'https://admob.googleapis.com/v1/$accountName/apps?pageSize=500';

    final response = await http.get(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    if (response.statusCode != 200) return [];

    try {
      final json = jsonDecode(response.body) as Map<String, dynamic>?;
      final list = json?['apps'] as List?;
      if (list == null) return [];

      final apps = <IronSourceApp>[];
      for (final item in list) {
        if (item is! Map<String, dynamic>) continue;
        final appId = item['appId'] as String? ?? '';
        if (appId.isEmpty) continue;
        final platform = (item['platform'] as String? ?? '').toLowerCase();
        String? displayName;
        final manual = item['manualAppInfo'] as Map<String, dynamic>?;
        final linked = item['linkedAppInfo'] as Map<String, dynamic>?;
        if (manual != null && manual['displayName'] != null) {
          displayName = manual['displayName'] as String?;
        }
        if ((displayName == null || displayName.isEmpty) && linked != null && linked['displayName'] != null) {
          displayName = linked['displayName'] as String?;
        }
        apps.add(IronSourceApp(
          appKey: appId,
          appName: displayName?.trim().isNotEmpty == true ? displayName : appId,
          platform: platform.isEmpty ? null : platform,
        ));
      }
      return apps;
    } catch (_) {
      return [];
    }
  }

  /// Valida credenciales: obtiene access token y llama accounts.get.
  Future<bool> validateCredentials() async {
    final publisherId = await _credentials.getAdMobPublisherId();
    if (publisherId == null || publisherId.trim().isEmpty) return false;
    final accessToken = await _getAccessToken();
    if (accessToken == null || accessToken.isEmpty) return false;

    final response = await http.get(
      Uri.parse(_accountsUrl),
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    if (response.statusCode != 200) return false;

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final accounts = json['account'] as List?;
    if (accounts == null || accounts.isEmpty) return false;

    final pubId = publisherId.trim();
    for (final a in accounts) {
      if (a is! Map<String, dynamic>) continue;
      final name = a['name'] as String? ?? '';
      if (name.contains(pubId) ||
          name.endsWith(pubId) ||
          pubId.contains(name.replaceAll('accounts/', ''))) {
        return true;
      }
      final pubIdFormatted = pubId.startsWith('pub-') ? pubId : 'pub-$pubId';
      if (name.contains(pubIdFormatted)) return true;
    }
    return true;
  }

  /// Devuelve stats desde la AdMob API (networkReport:generate).
  ///
  /// **Dimensiones usadas:** DATE, FORMAT, PLATFORM, COUNTRY
  /// (según [AdMob Report Metrics and Dimensions](https://developers.google.com/admob/api/v1/report-metrics-dimensions)).
  /// **Métricas:** ESTIMATED_EARNINGS, IMPRESSIONS, CLICKS, MATCHED_REQUESTS.
  /// **Filtros disponibles:** country (COUNTRY), platform (PLATFORM), adFormat (FORMAT).
  /// Filtro por App: opcional [appIds] (IDs de app AdMob, ej. ca-app-pub-xxx~yyy).
  Future<List<IronSourceStatsRow>> getStats({
    required String startDate,
    required String endDate,
    String? country,
    String? platform,
    String? adFormat,
    List<String>? appIds,
  }) async {
    final publisherId = await _credentials.getAdMobPublisherId();
    if (publisherId == null || publisherId.isEmpty) return [];

    final accessToken = await _getAccessToken();
    if (accessToken == null || accessToken.isEmpty) return [];

    final accountName = publisherId.startsWith('pub-')
        ? 'accounts/$publisherId'
        : 'accounts/pub-$publisherId';
    final url = 'https://admob.googleapis.com/v1/$accountName/networkReport:generate';

    final (startYear, startMonth, startDay) = _parseDate(startDate);
    final (endYear, endMonth, endDay) = _parseDate(endDate);

    final reportSpec = <String, dynamic>{
      'dateRange': {
        'startDate': {'year': startYear, 'month': startMonth, 'day': startDay},
        'endDate': {'year': endYear, 'month': endMonth, 'day': endDay},
      },
      'dimensions': ['DATE', 'FORMAT', 'PLATFORM', 'COUNTRY'],
      'metrics': [
        'ESTIMATED_EARNINGS',
        'IMPRESSIONS',
        'CLICKS',
        'MATCHED_REQUESTS',
      ],
    };

    final filters = <Map<String, dynamic>>[];
    if (country != null && country.trim().isNotEmpty) {
      filters.add({
        'dimension': 'COUNTRY',
        'matchesAny': {
          'values': country.split(',').map((v) => {'value': v.trim()}).where((m) => (m['value'] as String).isNotEmpty).toList(),
        },
      });
    }
    if (platform != null && platform.trim().isNotEmpty) {
      filters.add({
        'dimension': 'PLATFORM',
        'matchesAny': {
          'values': [{'value': platform.trim().toUpperCase()}],
        },
      });
    }
    if (adFormat != null && adFormat.trim().isNotEmpty) {
      filters.add({
        'dimension': 'FORMAT',
        'matchesAny': {
          'values': adFormat.split(',').map((v) => {'value': v.trim()}).where((m) => (m['value'] as String).isNotEmpty).toList(),
        },
      });
    }
    if (appIds != null && appIds.isNotEmpty) {
      filters.add({
        'dimension': 'APP',
        'matchesAny': {
          'values': appIds.map((id) => {'value': id.trim()}).where((m) => (m['value'] as String).isNotEmpty).toList(),
        },
      });
    }
    if (filters.isNotEmpty) reportSpec['dimensionFilters'] = filters;

    final body = jsonEncode({'reportSpec': reportSpec});

    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: body,
    );

    if (response.statusCode != 200) return [];

    return _parseReportResponse(response.body);
  }

  (int, int, int) _parseDate(String dateStr) {
    final parts = dateStr.split('-');
    if (parts.length >= 3) {
      final y = int.tryParse(parts[0]) ?? DateTime.now().year;
      final m = int.tryParse(parts[1]) ?? 1;
      final d = int.tryParse(parts[2]) ?? 1;
      return (y, m, d);
    }
    final dt = DateTime.tryParse(dateStr) ?? DateTime.now();
    return (dt.year, dt.month, dt.day);
  }

  List<IronSourceStatsRow> _parseReportResponse(String body) {
    final rows = <IronSourceStatsRow>[];

    try {
      final decoded = jsonDecode(body);
      if (decoded is List) {
        for (final item in decoded) {
          if (item is Map<String, dynamic> && item['row'] != null) {
            final r = _rowToStats(item['row'] as Map<String, dynamic>);
            if (r != null) rows.add(r);
          }
        }
      } else if (decoded is Map<String, dynamic>) {
        if (decoded['row'] != null) {
          final r = _rowToStats(decoded['row'] as Map<String, dynamic>);
          if (r != null) rows.add(r);
        }
      } else {
        for (final line in body.split('\n')) {
          final trimmed = line.trim();
          if (trimmed.isEmpty) continue;
          try {
            final item = jsonDecode(trimmed) as Map<String, dynamic>?;
            if (item != null && item['row'] != null) {
              final r = _rowToStats(item['row'] as Map<String, dynamic>);
              if (r != null) rows.add(r);
            }
          } catch (_) {}
        }
      }
    } catch (_) {}

    return rows;
  }

  IronSourceStatsRow? _rowToStats(Map<String, dynamic> row) {
    final dims = row['dimensionValues'] as Map<String, dynamic>? ?? {};
    final metrics = row['metricValues'] as Map<String, dynamic>? ?? {};

    String? dateVal;
    String? formatVal;
    String? platformVal;
    String? countryVal;

    for (final e in dims.entries) {
      final v = (e.value is Map) ? (e.value as Map)['value'] : e.value;
      final s = v?.toString().trim();
      if (s == null || s.isEmpty) continue;
      switch (e.key.toString().toUpperCase()) {
        case 'DATE':
          dateVal = s;
          break;
        case 'FORMAT':
          formatVal = s;
          break;
        case 'PLATFORM':
          platformVal = s;
          break;
        case 'COUNTRY':
          countryVal = s;
          break;
      }
    }

    double revenue = 0;
    int impressions = 0;
    int clicks = 0;
    int matchedRequests = 0;

    for (final e in metrics.entries) {
      final v = e.value;
      if (v is! Map) continue;
      final micros = v['microsValue'];
      final intVal = v['integerValue'];
      final numVal = v['value'];
      switch (e.key.toString().toUpperCase()) {
        case 'ESTIMATED_EARNINGS':
          revenue = _toDouble(micros, numVal) / 1e6;
          break;
        case 'IMPRESSIONS':
          impressions = _toInt(intVal, numVal);
          break;
        case 'CLICKS':
          clicks = _toInt(intVal, numVal);
          break;
        case 'MATCHED_REQUESTS':
          matchedRequests = _toInt(intVal, numVal);
          break;
      }
    }

    final double ctr = impressions > 0 ? (clicks / impressions) * 100 : 0;
    final double fillRate = matchedRequests > 0 ? (impressions / matchedRequests) * 100 : 0;
    final double completionRate = impressions > 0 ? (impressions / impressions) * 100 : 0;

    return IronSourceStatsRow(
      adUnits: formatVal,
      date: dateVal,
      platform: platformVal,
      country: countryVal,
      data: [
        {
          'revenue': revenue,
          'impressions': impressions,
          'clicks': clicks,
          'completions': impressions,
          'appRequests': matchedRequests,
          'appFillRate': fillRate,
          'completionRate': completionRate,
          'clickThroughRate': ctr,
          'revenuePerCompletion': impressions > 0 ? revenue / impressions : 0,
        },
      ],
    );
  }

  double _toDouble(dynamic micros, dynamic fallback) {
    if (micros is num) return micros.toDouble();
    if (fallback is num) return fallback.toDouble();
    if (fallback is String) return double.tryParse(fallback) ?? 0;
    return 0;
  }

  int _toInt(dynamic intVal, dynamic fallback) {
    if (intVal is int) return intVal;
    if (intVal is num) return intVal.toInt();
    if (fallback is int) return fallback;
    if (fallback is num) return fallback.toInt();
    if (fallback is String) return int.tryParse(fallback) ?? 0;
    return 0;
  }

  /// Valida que Publisher ID esté configurado (formato).
  Future<bool> validatePublisherId() async {
    final id = await _credentials.getAdMobPublisherId();
    if (id == null || id.trim().isEmpty) return false;
    final t = id.trim();
    return t.startsWith('pub-') ||
        t.startsWith('ca-app-pub-') ||
        RegExp(r'^\d+$').hasMatch(t);
  }
}
