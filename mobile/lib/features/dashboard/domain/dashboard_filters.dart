import 'dart:convert';

import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_constants.dart';

enum DateRangePreset { today, yesterday, last7, last30, last90, custom }

class DashboardFilters {
  const DashboardFilters({
    required this.startDate,
    required this.endDate,
    this.datePreset = DateRangePreset.last7,
    this.appKeys,
    this.platforms,
    this.adUnits,
    this.countries,
  });

  final DateTime startDate;
  final DateTime endDate;
  final DateRangePreset datePreset;
  /// Múltiples apps; null o vacío = todas.
  final List<String>? appKeys;
  /// Múltiples plataformas (android, ios); null o vacío = todas.
  final List<String>? platforms;
  /// Múltiples tipos de anuncio; null o vacío = todos.
  final List<String>? adUnits;
  /// Múltiples países (códigos); null o vacío = todos.
  final List<String>? countries;

  String get startDateStr => DateFormat('yyyy-MM-dd').format(startDate);
  String get endDateStr => DateFormat('yyyy-MM-dd').format(endDate);

  bool get hasAppFilter => appKeys != null && appKeys!.isNotEmpty;
  bool get hasPlatformFilter => platforms != null && platforms!.isNotEmpty;
  bool get hasAdUnitFilter => adUnits != null && adUnits!.isNotEmpty;
  bool get hasCountryFilter => countries != null && countries!.isNotEmpty;

  DashboardFilters copyWith({
    DateTime? startDate,
    DateTime? endDate,
    DateRangePreset? datePreset,
    List<String>? appKeys,
    List<String>? platforms,
    List<String>? adUnits,
    List<String>? countries,
    bool clearAppKeys = false,
    bool clearPlatforms = false,
    bool clearAdUnits = false,
    bool clearCountries = false,
  }) {
    return DashboardFilters(
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      datePreset: datePreset ?? this.datePreset,
      appKeys: clearAppKeys ? null : (appKeys ?? this.appKeys),
      platforms: clearPlatforms ? null : (platforms ?? this.platforms),
      adUnits: clearAdUnits ? null : (adUnits ?? this.adUnits),
      countries: clearCountries ? null : (countries ?? this.countries),
    );
  }

  static DashboardFilters last7Days() {
    final end = DateTime.now();
    final start = end.subtract(const Duration(days: 6));
    return DashboardFilters(
      startDate: DateTime(start.year, start.month, start.day),
      endDate: DateTime(end.year, end.month, end.day),
      datePreset: DateRangePreset.last7,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'datePreset': datePreset.index,
      'appKeys': appKeys,
      'platforms': platforms,
      'adUnits': adUnits,
      'countries': countries,
    };
  }

  static DashboardFilters fromJson(Map<String, dynamic>? json) {
    if (json == null) return DashboardFilters.last7Days();
    DateTime? start;
    DateTime? end;
    if (json['startDate'] is String) start = DateTime.tryParse(json['startDate'] as String);
    if (json['endDate'] is String) end = DateTime.tryParse(json['endDate'] as String);
    DateRangePreset? preset;
    if (json['datePreset'] is int) {
      final i = json['datePreset'] as int;
      if (i >= 0 && i < DateRangePreset.values.length) preset = DateRangePreset.values[i];
    }
    List<String>? list(dynamic v) {
      if (v == null) return null;
      if (v is List) return v.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
      return null;
    }
    final def = DashboardFilters.last7Days();
    return DashboardFilters(
      startDate: start ?? def.startDate,
      endDate: end ?? def.endDate,
      datePreset: preset ?? def.datePreset,
      appKeys: list(json['appKeys']),
      platforms: list(json['platforms']),
      adUnits: list(json['adUnits']),
      countries: list(json['countries']),
    );
  }

  static Future<void> saveDashboard(DashboardFilters f) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.storageDashboardFilters, jsonEncode(f.toJson()));
  }

  static Future<DashboardFilters> loadDashboard() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(AppConstants.storageDashboardFilters);
    if (raw == null) return DashboardFilters.last7Days();
    try {
      return DashboardFilters.fromJson(jsonDecode(raw) as Map<String, dynamic>?);
    } catch (_) {
      return DashboardFilters.last7Days();
    }
  }

  static Future<void> saveMetric(String metricId, DashboardFilters f) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('${AppConstants.storageMetricFiltersPrefix}$metricId', jsonEncode(f.toJson()));
  }

  static Future<DashboardFilters> loadMetric(String metricId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('${AppConstants.storageMetricFiltersPrefix}$metricId');
    if (raw == null) return DashboardFilters.last7Days();
    try {
      return DashboardFilters.fromJson(jsonDecode(raw) as Map<String, dynamic>?);
    } catch (_) {
      return DashboardFilters.last7Days();
    }
  }
}
