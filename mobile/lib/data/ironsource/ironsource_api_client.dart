import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/constants/app_constants.dart';
import '../credentials/credentials_repository.dart';

/// Fila de estadísticas (compatible con el formato antiguo para el dashboard).
class IronSourceStatsRow {
  IronSourceStatsRow({
    this.adUnits,
    this.date,
    this.platform,
    this.country,
    this.appKey,
    this.data,
  });

  final String? adUnits;
  final String? date;
  final String? platform;
  final String? country;
  final String? appKey;
  final List<Map<String, dynamic>>? data;

  static String? _str(Map<String, dynamic> j, String key, [String? altKey]) {
    final v = j[key] ?? (altKey != null ? j[altKey] : null);
    if (v == null) return null;
    final s = (v is String ? v : v.toString()).trim();
    return s.isEmpty ? null : s;
  }

  static String? _strFrom(Map<String, dynamic> json, List<String> keys) {
    for (final k in keys) {
      final v = _str(json, k);
      if (v != null) return v;
    }
    final dims = json['dimensions'];
    if (dims is Map<String, dynamic>) {
      for (final k in keys) {
        final v = _str(dims, k);
        if (v != null) return v;
      }
    }
    return null;
  }

  /// Desde la API v1 (LevelPlay): cada item de data es una fila plana.
  static IronSourceStatsRow fromReportingV1Row(Map<String, dynamic> json) {
    final adFormat = _strFrom(json, ['adFormat', 'adUnits', 'adUnit']);
    final date = _strFrom(json, ['date', 'day']);
    final platform = _strFrom(json, ['platform', 'os']);
    final country = _strFrom(json, ['country', 'countryCode', 'country_iso', 'country_code']);
    final app = _strFrom(json, ['app', 'appKey', 'applicationKey', 'application_key']);
    final revenue = (json['revenue'] is num) ? (json['revenue'] as num).toDouble() : 0.0;
    final impressions = (json['impressions'] is num) ? (json['impressions'] as num).toInt() : 0;
    final eCPM = (json['eCPM'] is num) ? (json['eCPM'] as num).toDouble() : 0.0;
    final clicks = (json['clicks'] is num) ? (json['clicks'] as num).toInt() : 0;
    final completions = (json['completions'] is num) ? (json['completions'] as num).toInt() : 0;
    return IronSourceStatsRow(
      adUnits: adFormat,
      date: date,
      platform: platform,
      country: country,
      appKey: app,
      data: [
        {
          'revenue': revenue,
          'impressions': impressions,
          'eCPM': eCPM,
          'clicks': clicks,
          'completions': completions,
        },
      ],
    );
  }
}

class IronSourceApiClient {
  IronSourceApiClient({
    CredentialsRepository? credentialsRepository,
    http.Client? client,
  })  : _credentials = credentialsRepository ?? CredentialsRepository(),
        _client = client ?? http.Client();

  final CredentialsRepository _credentials;
  final http.Client _client;

  /// Obtiene un Bearer token con Secret Key + Refresh Token (doc IronSource).
  Future<String> _getBearerToken() async {
    final creds = await _credentials.getCredentials();
    if (creds == null) throw Exception('Configura Secret Key y Refresh Token en Ajustes.');

    final response = await _client.get(
      Uri.parse(AppConstants.ironsourceAuthUrl),
      headers: {
        'secretkey': creds.secretKey,
        'refreshToken': creds.refreshToken,
      },
    );

    if (response.statusCode != 200) {
      throw Exception('IronSource Auth: ${response.statusCode} ${response.body}');
    }

    final token = response.body.trim().replaceAll('"', '');
    if (token.isEmpty) throw Exception('IronSource Auth: token vacío');
    return token;
  }

  /// LevelPlay Reporting API v1 (Bearer). Devuelve filas en formato compatible con el dashboard.
  Future<List<IronSourceStatsRow>> getStats({
    required String startDate,
    required String endDate,
    String? appKey,
    String? country,
    String? adUnits,
    String? breakdowns,
    String? metrics,
  }) async {
    final token = await _getBearerToken();

    // LevelPlay v1: breakdowns son date, adFormat, platform, country, app
    final queryParams = <String, String>{
      'startDate': startDate,
      'endDate': endDate,
      'metrics': metrics ?? 'revenue,impressions,eCPM,clicks,completions',
      'breakdowns': 'date,adFormat,platform,country,app',
      if (appKey != null && appKey.isNotEmpty) 'appKey': appKey,
      if (country != null && country.isNotEmpty) 'country': country,
      if (adUnits != null && adUnits.isNotEmpty) 'adFormat': adUnits,
    };

    final uri = Uri.parse(AppConstants.ironsourceReportingV1Url).replace(
      queryParameters: queryParams,
    );

    final response = await _client.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 200) {
      throw Exception('IronSource Reporting: ${response.statusCode} ${response.body}');
    }

    final body = json.decode(response.body) as Map<String, dynamic>?;
    final dataList = body?['data'] as List<dynamic>?;
    if (dataList == null) return [];

    return dataList
        .map((e) => IronSourceStatsRow.fromReportingV1Row(
              Map<String, dynamic>.from(e as Map),
            ))
        .toList();
  }

  static const String _applicationsV3Url =
      'https://platform.ironsrc.com/partners/publisher/applications/v3';

  /// Lista de aplicaciones (Bearer). Prueba v6; si 404, intenta v3.
  Future<List<IronSourceApp>> getApplications() async {
    final token = await _getBearerToken();
    final headers = {'Authorization': 'Bearer $token'};
    var response = await _client.get(Uri.parse(AppConstants.ironsourceApplicationsUrl), headers: headers);
    if (response.statusCode == 404) {
      response = await _client.get(Uri.parse(_applicationsV3Url), headers: headers);
    }
    if (response.statusCode != 200) return [];

    final body = json.decode(response.body);
    List<dynamic> list = [];
    if (body is List) {
      list = body;
    } else if (body is Map<String, dynamic>) {
      if (body['applications'] is List) list = body['applications'] as List;
      else if (body['data'] is List) list = body['data'] as List;
      else list = [body];
    }
    return list
        .map((e) => IronSourceApp.fromJson(Map<String, dynamic>.from(e as Map)))
        .where((a) => (a.appKey ?? '').isNotEmpty)
        .toList();
  }
}

class IronSourceApp {
  IronSourceApp({
    this.appKey,
    this.appName,
    this.platform,
    this.bundleId,
  });

  final String? appKey;
  final String? appName;
  final String? platform;
  final String? bundleId;

  factory IronSourceApp.fromJson(Map<String, dynamic> json) {
    final key = json['appKey'] ?? json['applicationKey'] ?? json['application_key'] ?? json['key'];
    final name = json['appName'] ?? json['application_name'] ?? json['name'];
    final plat = json['platform'] ?? json['os'];
    final bundle = json['bundleId'] ?? json['bundle_id'];
    return IronSourceApp(
      appKey: key is String ? key : key?.toString(),
      appName: name is String ? name : name?.toString(),
      platform: plat is String ? plat : plat?.toString(),
      bundleId: bundle is String ? bundle : bundle?.toString(),
    );
  }
}
