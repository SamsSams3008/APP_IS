import 'package:intl/intl.dart';

enum DateRangePreset { today, yesterday, last7, last30, last90, custom }

class DashboardFilters {
  const DashboardFilters({
    required this.startDate,
    required this.endDate,
    this.datePreset = DateRangePreset.last7,
    this.appKey,
    this.platform,
    this.adUnits,
    this.country,
  });

  final DateTime startDate;
  final DateTime endDate;
  final DateRangePreset datePreset;
  final String? appKey;
  final String? platform;
  final String? adUnits;
  final String? country;

  String get startDateStr => DateFormat('yyyy-MM-dd').format(startDate);
  String get endDateStr => DateFormat('yyyy-MM-dd').format(endDate);

  DashboardFilters copyWith({
    DateTime? startDate,
    DateTime? endDate,
    DateRangePreset? datePreset,
    String? appKey,
    String? platform,
    String? adUnits,
    String? country,
  }) {
    return DashboardFilters(
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      datePreset: datePreset ?? this.datePreset,
      appKey: appKey ?? this.appKey,
      platform: platform ?? this.platform,
      adUnits: adUnits ?? this.adUnits,
      country: country ?? this.country,
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
}
