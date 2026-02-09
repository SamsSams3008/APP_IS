import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/constants/app_constants.dart';
import '../credentials/credentials_repository.dart';

/// Raw response item from IronSource stats API.
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

  factory IronSourceStatsRow.fromJson(Map<String, dynamic> json) {
    final dataList = json['data'];
    return IronSourceStatsRow(
      adUnits: json['adUnits'] as String?,
      date: json['date'] as String?,
      platform: json['platform'] as String?,
      country: json['country'] as String?,
      appKey: json['appKey'] as String?,
      data: dataList is List
          ? (dataList as List).map((e) => Map<String, dynamic>.from(e as Map<dynamic, dynamic>)).toList()
          : null,
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

  Future<List<IronSourceStatsRow>> getStats({
    required String startDate,
    required String endDate,
    String? appKey,
    String? country,
    String? adUnits,
    String? breakdowns,
    String? metrics,
  }) async {
    final creds = await _credentials.getCredentials();
    if (creds == null) throw Exception('Configura tus claves IronSource en Ajustes.');

    final uri = Uri.parse(AppConstants.ironsourceStatsBaseUrl).replace(
      queryParameters: <String, String>{
        'startDate': startDate,
        'endDate': endDate,
        if (appKey != null && appKey.isNotEmpty) 'appKey': appKey,
        if (country != null && country.isNotEmpty) 'country': country,
        if (adUnits != null && adUnits.isNotEmpty) 'adUnits': adUnits,
        if (breakdowns != null && breakdowns.isNotEmpty) 'breakdowns': breakdowns,
        if (metrics != null && metrics.isNotEmpty) 'metrics': metrics,
      },
    );

    final response = await _client.get(
      uri,
      headers: {'Authorization': creds.basicAuthHeader},
    );

    if (response.statusCode != 200) {
      throw Exception('IronSource API: ${response.statusCode} ${response.body}');
    }

    final list = json.decode(response.body) as List<dynamic>?;
    if (list == null) return [];
    return list
        .map((e) => IronSourceStatsRow.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<IronSourceApp>> getApplications() async {
    final creds = await _credentials.getCredentials();
    if (creds == null) throw Exception('Configura tus claves IronSource en Ajustes.');

    final uri = Uri.parse(AppConstants.ironsourceApplicationsUrl);
    final response = await _client.get(
      uri,
      headers: {'Authorization': creds.basicAuthHeader},
    );

    if (response.statusCode != 200) {
      throw Exception('IronSource API: ${response.statusCode} ${response.body}');
    }

    final body = json.decode(response.body);
    if (body is List) {
      return body
          .map((e) => IronSourceApp.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    if (body is Map) {
      return [IronSourceApp.fromJson(Map<String, dynamic>.from(body))];
    }
    return [];
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
    final name = json['appName'] ?? json['application_name'];
    return IronSourceApp(
      appKey: json['appKey'] as String?,
      appName: name is String ? name : null,
      platform: json['platform'] as String?,
      bundleId: json['bundleId'] ?? json['bundle_id'] as String?,
    );
  }
}
