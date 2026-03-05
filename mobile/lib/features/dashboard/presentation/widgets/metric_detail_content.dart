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

  /// Misma lógica que DashboardRepository.statsFromRows para que Home y Detalles coincidan.
  double _totalValueForMetric() {
    double revenue = 0, fillRateSum = 0, completionRateSum = 0, revPerCompSum = 0, ctrSum = 0;
    int impressions = 0, clicks = 0, completions = 0, appRequests = 0, dau = 0, sessions = 0;
    int fillRateCount = 0, completionRateCount = 0, revPerCompCount = 0, ctrCount = 0;
    for (final row in rawRows) {
      for (final d in row.data ?? []) {
        revenue += _revNum(d['revenue']);
        impressions += (d['impressions'] is num) ? (d['impressions'] as num).toInt() : 0;
        clicks += (d['clicks'] is num) ? (d['clicks'] as num).toInt() : 0;
        completions += (d['completions'] is num) ? (d['completions'] as num).toInt() : 0;
        appRequests += (d['appRequests'] is num) ? (d['appRequests'] as num).toInt() : 0;
        dau += (d['dau'] is num) ? (d['dau'] as num).toInt() : 0;
        sessions += (d['sessions'] is num) ? (d['sessions'] as num).toInt() : 0;
        final fr = _revNum(d['appFillRate']);
        if (fr > 0) { fillRateSum += fr; fillRateCount++; }
        final cr = _revNum(d['completionRate']);
        if (cr > 0) { completionRateSum += cr; completionRateCount++; }
        final rpc = _revNum(d['revenuePerCompletion']);
        if (rpc > 0) { revPerCompSum += rpc; revPerCompCount++; }
        final ctr = _revNum(d['clickThroughRate']);
        if (ctr > 0) { ctrSum += ctr; ctrCount++; }
      }
    }
    switch (metricId) {
      case 'revenue':
        return revenue;
      case 'impressions':
        return impressions.toDouble();
      case 'ecpm':
        return impressions > 0 ? (revenue / impressions) * 1000 : 0;
      case 'clicks':
        return clicks.toDouble();
      case 'completions':
        return completions.toDouble();
      case 'fill_rate':
        return fillRateCount > 0 ? fillRateSum / fillRateCount : 0;
      case 'completion_rate':
        return completionRateCount > 0 ? completionRateSum / completionRateCount : (impressions > 0 && completions > 0 ? (completions / impressions) * 100 : 0);
      case 'ctr':
        return ctrCount > 0 ? ctrSum / ctrCount : (impressions > 0 && clicks > 0 ? (clicks / impressions) * 100 : 0);
      case 'revenue_per_completion':
        return revPerCompCount > 0 ? revPerCompSum / revPerCompCount : (completions > 0 ? revenue / completions : 0);
      case 'app_requests':
        return appRequests.toDouble();
      case 'dau':
        return dau.toDouble();
      case 'sessions':
        return sessions.toDouble();
      default:
        return revenue;
    }
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
    // Para métricas ratio: agregar numerador/denominador por fecha y luego calcular.
    final byDate = <String, Map<String, num>>{};
    for (final row in rawRows) {
      final date = row.date ?? '';
      if (date.isEmpty) continue;
      if (!byDate.containsKey(date)) {
        byDate[date] = {'rev': 0, 'imp': 0, 'clicks': 0, 'comp': 0, 'fr': 0, 'frN': 0, 'cr': 0, 'crN': 0, 'ctr': 0, 'ctrN': 0, 'rpc': 0, 'rpcN': 0, 'appReq': 0, 'dau': 0, 'sess': 0};
      }
      final acc = byDate[date]!;
      for (final d in row.data ?? []) {
        final rev = _revNum(d['revenue']);
        final imp = (d['impressions'] is num) ? (d['impressions'] as num).toInt() : 0;
        final clk = (d['clicks'] is num) ? (d['clicks'] as num).toInt() : 0;
        final comp = (d['completions'] is num) ? (d['completions'] as num).toInt() : 0;
        acc['rev'] = (acc['rev'] as num) + rev;
        acc['imp'] = (acc['imp'] as num) + imp;
        acc['clicks'] = (acc['clicks'] as num) + clk;
        acc['comp'] = (acc['comp'] as num) + comp;
        acc['appReq'] = (acc['appReq'] as num) + (d['appRequests'] is num ? (d['appRequests'] as num).toInt() : 0);
        acc['dau'] = (acc['dau'] as num) + (d['dau'] is num ? (d['dau'] as num).toInt() : 0);
        acc['sess'] = (acc['sess'] as num) + (d['sessions'] is num ? (d['sessions'] as num).toInt() : 0);
        final fr = _revNum(d['appFillRate']);
        if (fr > 0) { acc['fr'] = (acc['fr'] as num) + fr; acc['frN'] = (acc['frN'] as num) + 1; }
        final cr = _revNum(d['completionRate']);
        if (cr > 0) { acc['cr'] = (acc['cr'] as num) + cr; acc['crN'] = (acc['crN'] as num) + 1; }
        final ctr = _revNum(d['clickThroughRate']);
        if (ctr > 0) { acc['ctr'] = (acc['ctr'] as num) + ctr; acc['ctrN'] = (acc['ctrN'] as num) + 1; }
        final rpc = _revNum(d['revenuePerCompletion']);
        if (rpc > 0) { acc['rpc'] = (acc['rpc'] as num) + rpc; acc['rpcN'] = (acc['rpcN'] as num) + 1; }
      }
    }
    final result = <MapEntry<String, double>>[];
    for (final e in byDate.entries.toList()..sort((a, b) => a.key.compareTo(b.key))) {
      final d = e.value;
      double v = 0;
      switch (metricId) {
        case 'revenue':
          v = (d['rev'] as num).toDouble();
          break;
        case 'impressions':
          v = (d['imp'] as num).toDouble();
          break;
        case 'ecpm':
          final imp = d['imp'] as num;
          v = imp > 0 ? ((d['rev'] as num) / imp * 1000).toDouble() : 0;
          break;
        case 'clicks':
          v = (d['clicks'] as num).toDouble();
          break;
        case 'completions':
          v = (d['comp'] as num).toDouble();
          break;
        case 'fill_rate':
          v = (d['frN'] as num) > 0 ? (d['fr'] as num) / (d['frN'] as num) : 0;
          break;
        case 'completion_rate':
          v = (d['crN'] as num) > 0 ? (d['cr'] as num) / (d['crN'] as num) : ((d['imp'] as num) > 0 && (d['comp'] as num) > 0 ? (d['comp'] as num) / (d['imp'] as num) * 100 : 0).toDouble();
          break;
        case 'ctr':
          v = (d['ctrN'] as num) > 0 ? (d['ctr'] as num) / (d['ctrN'] as num) : ((d['imp'] as num) > 0 && (d['clicks'] as num) > 0 ? (d['clicks'] as num) / (d['imp'] as num) * 100 : 0).toDouble();
          break;
        case 'revenue_per_completion':
          v = (d['rpcN'] as num) > 0 ? (d['rpc'] as num) / (d['rpcN'] as num) : ((d['comp'] as num) > 0 ? (d['rev'] as num) / (d['comp'] as num) : 0).toDouble();
          break;
        case 'app_requests':
          v = (d['appReq'] as num).toDouble();
          break;
        case 'dau':
          v = (d['dau'] as num).toDouble();
          break;
        case 'sessions':
          v = (d['sess'] as num).toDouble();
          break;
        default:
          v = (d['rev'] as num).toDouble();
      }
      result.add(MapEntry(e.key, v));
    }
    return result;
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
