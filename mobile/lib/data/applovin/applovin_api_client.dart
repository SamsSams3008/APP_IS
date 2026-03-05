import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../credentials/credentials_repository.dart';
import '../ironsource/ironsource_api_client.dart';

/// AppLovin MAX Revenue Reporting API client.
/// Docs: https://developers.applovin.com/en/max/reporting-apis/revenue-reporting-api/
///
/// Available columns: day, application, impressions, estimated_revenue, ecpm,
/// country, platform, ad_format, package_name, store_id.
/// AppLovin does NOT provide: clicks, completions, fill_rate, completion_rate,
/// revenue_per_completion, ctr, app_requests, dau, sessions.
class AppLovinApiClient {
  AppLovinApiClient({
    CredentialsRepository? credentialsRepository,
    http.Client? client,
  })  : _credentials = credentialsRepository ?? CredentialsRepository(),
        _client = client ?? http.Client();

  final CredentialsRepository _credentials;
  final http.Client _client;

  static const String _baseUrl = 'https://r.applovin.com/maxReport';

  static bool _isDemoKey(String? key) {
    final k = (key ?? '').trim().toLowerCase();
    return k == 'demo' || k == 'test' || k == 'hola';
  }

  Future<String> _getReportKey() async {
    final key = await _credentials.getAppLovinReportKey();
    if (key == null || key.trim().isEmpty) {
      throw Exception('Configura el Report Key de AppLovin en Ajustes.');
    }
    return key.trim();
  }

  /// IronSource-style -> AppLovin: interstitial->INTER, rewardedVideo->REWARD, banner->BANNER
  static String? _toAppLovinAdFormat(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    switch (v.trim().toLowerCase()) {
      case 'interstitial':
        return 'INTER';
      case 'rewardedvideo':
      case 'rewarded':
        return 'REWARD';
      case 'banner':
        return 'BANNER';
      default:
        return v.trim().toUpperCase();
    }
  }

  /// Map AppLovin ad_format to IronSource-style: INTER->interstitial, REWARD->rewardedVideo, BANNER->banner
  static String? _mapAdFormat(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    switch (v.toUpperCase()) {
      case 'INTER':
        return 'interstitial';
      case 'REWARD':
        return 'rewardedVideo';
      case 'BANNER':
        return 'banner';
      default:
        return v.trim().toLowerCase();
    }
  }

  static double _num(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  static String? _str(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  /// Genera datos demo (solo revenue, impressions, eCPM - igual que AppLovin real).
  static List<IronSourceStatsRow> _mockStats(String startDate, String endDate) {
    final rows = <IronSourceStatsRow>[];
    final rnd = Random(42);
    final platforms = ['android', 'ios'];
    final countries = ['US', 'GB', 'DE', 'ES', 'FR'];
    const adFormats = ['rewardedVideo', 'interstitial', 'banner'];
    DateTime start;
    DateTime end;
    try {
      start = DateTime.parse(startDate);
      end = DateTime.parse(endDate);
    } catch (_) {
      end = DateTime.now();
      start = end.subtract(const Duration(days: 6));
    }
    var d = DateTime(start.year, start.month, start.day);
    final endDay = DateTime(end.year, end.month, end.day);
    while (!d.isAfter(endDay)) {
      final dayStr = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      for (final platform in platforms) {
        for (final adFormat in adFormats) {
          if (rnd.nextDouble() > 0.5) continue;
          final country = countries[rnd.nextInt(countries.length)];
          final imp = 800 + rnd.nextInt(4000);
          final ecpm = 3.0 + rnd.nextDouble() * 12;
          final rev = (imp * ecpm) / 1000;
          rows.add(IronSourceStatsRow(
            adUnits: adFormat,
            date: dayStr,
            platform: platform,
            country: country,
            appKey: 'com.example.demo',
            data: [
              {
                'revenue': rev,
                'impressions': imp,
                'eCPM': ecpm,
                'clicks': 0,
                'completions': 0,
                'appFillRate': 0.0,
                'completionRate': null,
                'revenuePerCompletion': null,
                'clickThroughRate': null,
                'appRequests': 0,
                'dau': 0,
                'sessions': 0,
              },
            ],
          ));
        }
      }
      d = d.add(const Duration(days: 1));
    }
    return rows;
  }

  /// Fetches stats from AppLovin MAX Report API.
  /// Returns rows in IronSourceStatsRow format; only revenue, impressions, eCPM
  /// are populated. Other metrics (clicks, completions, etc.) are 0/null.
  /// Use Report Key "demo", "test" o "hola" para datos de prueba (solo 3 métricas).
  Future<List<IronSourceStatsRow>> getStats({
    required String startDate,
    required String endDate,
    String? country,
    String? platform,
    String? adFormat,
  }) async {
    final apiKey = await _getReportKey();
    if (_isDemoKey(apiKey)) {
      return _mockStats(startDate, endDate);
    }
    final columns =
        'day,application,impressions,estimated_revenue,ecpm,country,platform,ad_format,package_name';
    final params = <String, String>{
      'api_key': apiKey,
      'columns': columns,
      'start': startDate,
      'end': endDate,
      'format': 'json',
      'limit': '5000',
    };
    if (country != null && country.isNotEmpty) params['filter_country'] = country;
    if (platform != null && platform.isNotEmpty) params['filter_platform'] = platform;
    if (adFormat != null && adFormat.isNotEmpty) {
      final applovinFormat = _toAppLovinAdFormat(adFormat);
      if (applovinFormat != null) params['filter_ad_format'] = applovinFormat;
    }

    final uri = Uri.parse(_baseUrl).replace(queryParameters: params);
    final response = await _client.get(uri);

    if (response.statusCode != 200) {
      throw Exception('AppLovin Report: ${response.statusCode} ${response.body}');
    }

    final body = json.decode(response.body);
    List<dynamic> rows;
    if (body is List) {
      rows = body;
    } else if (body is Map<String, dynamic>) {
      final data = body['results'] ?? body['data'] ?? body['rows'];
      rows = data is List ? data : [body];
    } else {
      rows = [];
    }

    final result = <IronSourceStatsRow>[];
    for (final r in rows) {
      final m = r is Map ? Map<String, dynamic>.from(r) : <String, dynamic>{};
      final day = _str(m['day']) ?? _str(m['date']) ?? '';
      final appName = _str(m['application']) ?? '';
      final pkg = _str(m['package_name']) ?? _str(m['store_id']) ?? '';
      final appKey = pkg.isNotEmpty ? pkg : (appName.isNotEmpty ? appName : 'unknown');
      final platformStr = _str(m['platform'])?.toLowerCase();
      final countryStr = _str(m['country'])?.toUpperCase();
      final adFormatStr = _mapAdFormat(_str(m['ad_format']));

      final revenue = _num(m['estimated_revenue']) > 0 ? _num(m['estimated_revenue']) : _num(m['revenue']);
      final impressions = _num(m['impressions']).toInt();
      final ecpm = _num(m['ecpm']);
      final ecpmComputed = impressions > 0 && revenue > 0 ? (revenue / impressions) * 1000 : ecpm;

      result.add(IronSourceStatsRow(
        adUnits: adFormatStr,
        date: day,
        platform: platformStr,
        country: countryStr,
        appKey: appKey,
        data: [
          {
            'revenue': revenue,
            'impressions': impressions,
            'eCPM': ecpmComputed > 0 ? ecpmComputed : ecpm,
            'clicks': 0,
            'completions': 0,
            'appFillRate': 0.0,
            'completionRate': null,
            'revenuePerCompletion': null,
            'clickThroughRate': null,
            'appRequests': 0,
            'dau': 0,
            'sessions': 0,
          },
        ],
      ));
    }
    return result;
  }

  /// AppLovin does not expose an applications list API in the same way.
  /// We validate by making a small report request.
  /// Keys "demo" or "test" are always valid for mock data.
  Future<bool> validateReportKey() async {
    try {
      final key = await _credentials.getAppLovinReportKey();
      if (key == null || key.trim().isEmpty) return false;
      if (_isDemoKey(key)) return true;
      final end = DateTime.now();
      final start = end.subtract(const Duration(days: 1));
      final uri = Uri.parse(_baseUrl).replace(queryParameters: {
        'api_key': key.trim(),
        'columns': 'day,impressions',
        'start': '${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}',
        'end': '${end.year}-${end.month.toString().padLeft(2, '0')}-${end.day.toString().padLeft(2, '0')}',
        'format': 'json',
        'limit': '1',
      });
      final response = await _client.get(uri);
      if (response.statusCode == 401 || response.statusCode == 403) return false;
      if (response.statusCode != 200) return false;
      return true;
    } catch (_) {
      return false;
    }
  }
}
