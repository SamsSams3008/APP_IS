import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/l10n/app_strings.dart';
import '../../../../core/locale_notifier.dart';
import '../../../../data/ironsource/ironsource_api_client.dart';
import '../../../../shared/utils/formatters.dart';
import '../../../glossary/glossary_data.dart';
import '../../domain/dashboard_filters.dart';
import '../../domain/dashboard_stats.dart';

double _revNum(Object? v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0;
  return 0;
}

/// Widget que muestra valor, gráfica y glosario de una métrica (sin botón).
class MetricDetailContent extends StatelessWidget {
  const MetricDetailContent({
    super.key,
    required this.rawRows,
    required this.filters,
    required this.prevStats,
    required this.metricId,
  });

  final List<IronSourceStatsRow> rawRows;
  final DashboardFilters filters;
  final DashboardStats? prevStats;
  final String metricId;

  double _totalValueForMetric() {
    double total = 0;
    int totalImpressions = 0;
    double totalRevenue = 0;
    int rateCount = 0;
    for (final row in rawRows) {
      for (final d in row.data ?? []) {
        switch (metricId) {
          case 'revenue':
            total += _revNum(d['revenue']);
            break;
          case 'impressions':
            total += (d['impressions'] is num) ? (d['impressions'] as num).toDouble() : 0;
            break;
          case 'ecpm':
            totalRevenue += _revNum(d['revenue']);
            totalImpressions += (d['impressions'] is num) ? (d['impressions'] as num).toInt() : 0;
            break;
          case 'clicks':
            total += (d['clicks'] is num) ? (d['clicks'] as num).toDouble() : 0;
            break;
          case 'completions':
            total += (d['completions'] is num) ? (d['completions'] as num).toDouble() : 0;
            break;
          case 'fill_rate':
            total += (d['appFillRate'] is num) ? (d['appFillRate'] as num).toDouble() : 0;
            rateCount++;
            break;
          case 'completion_rate':
            total += (d['completionRate'] is num) ? (d['completionRate'] as num).toDouble() : 0;
            rateCount++;
            break;
          case 'ctr':
            total += (d['clickThroughRate'] is num) ? (d['clickThroughRate'] as num).toDouble() : 0;
            rateCount++;
            break;
          case 'revenue_per_completion':
            total += (d['revenuePerCompletion'] is num) ? (d['revenuePerCompletion'] as num).toDouble() : 0;
            break;
          case 'app_requests':
            total += (d['appRequests'] is num) ? (d['appRequests'] as num).toDouble() : 0;
            break;
          case 'dau':
            total += (d['dau'] is num) ? (d['dau'] as num).toDouble() : 0;
            break;
          case 'sessions':
            total += (d['sessions'] is num) ? (d['sessions'] as num).toDouble() : 0;
            break;
          default:
            total += _revNum(d['revenue']);
        }
      }
    }
    if (metricId == 'revenue') return total;
    if (metricId == 'ecpm' && totalImpressions > 0) return (totalRevenue / totalImpressions) * 1000;
    if (rateCount > 0) return total / rateCount;
    return total;
  }

  double? _prevValueForMetric() {
    final prev = prevStats;
    if (prev == null) return null;
    switch (metricId) {
      case 'revenue':
        return prev.revenue > 0 ? prev.revenue.toDouble() : null;
      case 'impressions':
        return prev.impressions > 0 ? prev.impressions.toDouble() : null;
      case 'ecpm':
        return prev.ecpm > 0 ? prev.ecpm : null;
      case 'clicks':
        return (prev.clicks ?? 0) > 0 ? (prev.clicks!).toDouble() : null;
      case 'completions':
        return (prev.completions ?? 0) > 0 ? (prev.completions!).toDouble() : null;
      case 'fill_rate':
        return (prev.fillRate ?? 0) > 0 ? prev.fillRate : null;
      case 'completion_rate':
        return (prev.completionRate ?? 0) > 0 ? prev.completionRate : null;
      case 'revenue_per_completion':
        return (prev.revenuePerCompletion ?? 0) > 0 ? prev.revenuePerCompletion : null;
      case 'ctr':
        return (prev.ctr ?? 0) > 0 ? prev.ctr : null;
      case 'app_requests':
        return (prev.appRequests ?? 0) > 0 ? (prev.appRequests!).toDouble() : null;
      case 'dau':
        return (prev.dau ?? 0) > 0 ? (prev.dau!).toDouble() : null;
      case 'sessions':
        return (prev.sessions ?? 0) > 0 ? (prev.sessions!).toDouble() : null;
      default:
        return null;
    }
  }

  List<MapEntry<String, double>> _entriesByDate() {
    final byDate = <String, double>{};
    for (final row in rawRows) {
      final date = row.date ?? '';
      if (date.isEmpty) continue;
      for (final d in row.data ?? []) {
        double v = 0;
        switch (metricId) {
          case 'revenue':
            v = _revNum(d['revenue']);
            break;
          case 'impressions':
            v = (d['impressions'] is num) ? (d['impressions'] as num).toDouble() : 0;
            break;
          case 'ecpm':
            final rev = _revNum(d['revenue']);
            final imp = (d['impressions'] is num) ? (d['impressions'] as num).toInt() : 0;
            v = imp > 0 ? (rev / imp) * 1000 : 0;
            break;
          case 'clicks':
            v = (d['clicks'] is num) ? (d['clicks'] as num).toDouble() : 0;
            break;
          case 'completions':
            v = (d['completions'] is num) ? (d['completions'] as num).toDouble() : 0;
            break;
          case 'fill_rate':
            v = (d['appFillRate'] is num) ? (d['appFillRate'] as num).toDouble() : 0;
            break;
          case 'completion_rate':
            v = (d['completionRate'] is num) ? (d['completionRate'] as num).toDouble() : 0;
            break;
          case 'revenue_per_completion':
            v = (d['revenuePerCompletion'] is num) ? (d['revenuePerCompletion'] as num).toDouble() : 0;
            break;
          case 'ctr':
            v = (d['clickThroughRate'] is num) ? (d['clickThroughRate'] as num).toDouble() : 0;
            break;
          case 'app_requests':
            v = (d['appRequests'] is num) ? (d['appRequests'] as num).toDouble() : 0;
            break;
          case 'dau':
            v = (d['dau'] is num) ? (d['dau'] as num).toDouble() : 0;
            break;
          case 'sessions':
            v = (d['sessions'] is num) ? (d['sessions'] as num).toDouble() : 0;
            break;
          default:
            v = _revNum(d['revenue']);
        }
        byDate[date] = (byDate[date] ?? 0) + v;
      }
    }
    final list = byDate.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    return list;
  }

  static double _niceIntervalAtLeast(double minInterval) {
    if (minInterval <= 0) return 1;
    const candidates = [0.01, 0.02, 0.05, 0.1, 0.2, 0.25, 0.5, 1.0, 2.0, 5.0, 10.0, 20.0, 50.0, 100.0];
    for (final c in candidates) {
      if (c >= minInterval) return c;
    }
    return (minInterval / 50).ceilToDouble() * 50;
  }

  String _formatChartValue(double value) {
    switch (metricId) {
      case 'revenue':
      case 'revenue_per_completion':
      case 'ecpm':
        return formatMoney(value);
      case 'impressions':
      case 'clicks':
      case 'completions':
      case 'app_requests':
      case 'dau':
      case 'sessions':
        return formatNumber(value.round());
      case 'fill_rate':
      case 'completion_rate':
      case 'ctr':
        return formatPercent(value);
      default:
        return value.toString();
    }
  }

  String _metricPrevPeriodLabel(String locale) {
    switch (filters.datePreset) {
      case DateRangePreset.today:
        return AppStrings.t('prev_today', locale);
      case DateRangePreset.yesterday:
        return AppStrings.t('prev_yesterday', locale);
      case DateRangePreset.last7:
        return AppStrings.t('prev_7_days', locale);
      case DateRangePreset.last30:
        return AppStrings.t('prev_30_days', locale);
      case DateRangePreset.last90:
        return AppStrings.t('prev_90_days', locale);
      case DateRangePreset.custom:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = LocaleNotifier.current;
    final entry = getGlossaryEntry(metricId);
    final title = entry != null ? getGlossaryTitle(entry.id, locale) : metricId;
    final value = _totalValueForMetric();
    final prevValue = _prevValueForMetric();
    final showCompare = filters.datePreset != DateRangePreset.custom &&
        prevValue != null &&
        prevValue > 0;
    double? pct;
    if (showCompare) {
      pct = ((value - prevValue) / prevValue) * 100;
    }
    final prevLabel = _metricPrevPeriodLabel(locale);

    const heroBlueStart = Color(0xFF0D47A1);
    const heroBlueEnd = Color(0xFF1565C0);
    const heroTextPrimary = Color(0xFFFFFFFF);
    const heroTextMuted = Color(0xFFBBDEFB);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                AppStrings.t('swipe_other_metrics', locale),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 10,
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.swipe_left, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ],
          ),
          const SizedBox(height: 6),
          // Hero card: valor + % de crecimiento (mismo azul que la principal)
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            clipBehavior: Clip.antiAlias,
            child: Container(
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.all(Radius.circular(16)),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [heroBlueStart, heroBlueEnd],
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: heroTextMuted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatChartValue(value),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: heroTextPrimary,
                    ),
                  ),
                  if (pct != null && prevLabel.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      '${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(1)}% $prevLabel',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: pct >= 0 ? const Color(0xFFA5D6A7) : const Color(0xFFEF9A9A),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Gráfica
          _buildChart(context),
          // Glosario ¿Qué es?
          if (entry != null) ...[
            const SizedBox(height: 20),
            _buildDescriptionCard(context, entry),
          ],
        ],
      ),
    );
  }

  Widget _buildChart(BuildContext context) {
    final entries = _entriesByDate();
    if (entries.isEmpty) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(child: Text(AppStrings.t('no_data_metric', LocaleNotifier.current))),
        ),
      );
    }

    final dataMaxY = entries.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    final minY = 0.0;
    final range = (dataMaxY - minY).clamp(0.01, double.infinity);
    final yInterval = _niceIntervalAtLeast(range / 7);
    final numSteps = (range / yInterval).ceil().clamp(1, 7);
    final maxY = minY + yInterval * numSteps;
    final spots = entries.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.value)).toList();
    final cs = Theme.of(context).colorScheme;
    final glossEntry = getGlossaryEntry(metricId);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF5BA3E8).withValues(alpha: 0.12),
              cs.tertiary.withValues(alpha: 0.06),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (glossEntry != null)
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF5BA3E8).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(glossEntry.icon, color: const Color(0xFF5BA3E8), size: 20),
                    ),
                  const SizedBox(width: 10),
                  Text(
                    glossEntry != null ? getGlossaryTitle(glossEntry.id, LocaleNotifier.current) : metricId,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 260,
                child: LineChart(
                  LineChartData(
                    minY: minY,
                    maxY: maxY <= 0 ? 1 : maxY,
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        fitInsideHorizontally: true,
                        fitInsideVertically: true,
                        tooltipMargin: 8,
                        getTooltipItems: (touchedSpots) => touchedSpots.map((s) {
                          final i = s.x.toInt();
                          final dateLabel = i >= 0 && i < entries.length
                              ? (entries[i].key.length >= 10 ? entries[i].key.substring(0, 10) : entries[i].key)
                              : '';
                          return LineTooltipItem(
                            '$dateLabel\n${_formatChartValue(s.y)}',
                            TextStyle(
                              color: Theme.of(context).colorScheme.onInverseSurface,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          );
                        }).toList(),
                        tooltipBorderRadius: BorderRadius.circular(8),
                        tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        getTooltipColor: (_) => Theme.of(context).colorScheme.inverseSurface,
                      ),
                    ),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: yInterval,
                      getDrawingHorizontalLine: (v) => FlLine(
                        color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
                        strokeWidth: 1,
                      ),
                    ),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 52,
                          interval: yInterval,
                          getTitlesWidget: (value, meta) => Text(
                            _formatChartValue(value),
                            style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant),
                            overflow: TextOverflow.clip,
                            maxLines: 1,
                          ),
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 32,
                          interval: (entries.length <= 5) ? 1 : ((entries.length - 1) / 4).clamp(1.0, double.infinity),
                          getTitlesWidget: (value, meta) {
                            final i = value.round();
                            if (i >= 0 && i < entries.length) {
                              final label = entries[i].key.length >= 10 ? entries[i].key.substring(5, 10) : entries[i].key;
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  label,
                                  style: TextStyle(fontSize: 9, color: Theme.of(context).colorScheme.onSurfaceVariant),
                                  overflow: TextOverflow.clip,
                                  maxLines: 1,
                                ),
                              );
                            }
                            return const SizedBox();
                          },
                        ),
                      ),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: false,
                        barWidth: 2.5,
                        color: const Color(0xFF5BA3E8),
                        dotData: FlDotData(
                          show: spots.length <= 25,
                          getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                            radius: 3,
                            color: const Color(0xFF5BA3E8),
                            strokeWidth: 0,
                          ),
                        ),
                        belowBarData: BarAreaData(
                          show: true,
                          color: const Color(0xFF5BA3E8).withValues(alpha: 0.12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDescriptionCard(BuildContext context, GlossaryEntry entry) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              cs.tertiary.withValues(alpha: 0.08),
              cs.primary.withValues(alpha: 0.05),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: cs.tertiary.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.info_outline, color: cs.primary, size: 20),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    AppStrings.t('what_is', LocaleNotifier.current),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                getGlossaryDescription(entry.id, LocaleNotifier.current),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
