import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../data/credentials/credentials_repository.dart';
import '../../../../data/ironsource/ironsource_api_client.dart';
import '../../../../shared/utils/formatters.dart';
import '../../../../shared/widgets/stat_card.dart';
import '../../data/dashboard_repository.dart';
import '../../domain/dashboard_filters.dart';
import '../../domain/dashboard_stats.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final DashboardRepository _repo = DashboardRepository();
  final CredentialsRepository _credentials = CredentialsRepository();

  DashboardFilters _filters = DashboardFilters.last7Days();
  DashboardStats? _stats;
  List<IronSourceStatsRow> _rawRows = [];
  List<IronSourceApp> _apps = [];
  bool _loading = true;
  String? _error;

  // Cache: una petición por rango de fechas; filtros en memoria
  List<IronSourceStatsRow> _cachedRawRows = [];
  String? _cachedStartDate;
  String? _cachedEndDate;

  @override
  void initState() {
    super.initState();
    _checkCredentials();
  }

  Future<void> _checkCredentials() async {
    final hasCredentials = await _credentials.hasCredentials();
    if (!mounted) return;
    if (!hasCredentials) {
      context.push('/credentials');
      return;
    }
    _load();
  }

  bool get _isCacheValid =>
      _cachedStartDate == _filters.startDateStr &&
      _cachedEndDate == _filters.endDateStr &&
      _cachedRawRows.isNotEmpty;

  bool _isEmptyFilter(String? v) => v == null || v.isEmpty;

  /// Filtra en memoria: aplica todos los filtros a la vez (app + tipo anuncio + país + plataforma).
  void _applyFiltersFromCache() {
    if (_cachedRawRows.isEmpty) return;
    final filtered = _cachedRawRows.where((row) {
      if (!_isEmptyFilter(_filters.appKey) && (row.appKey ?? '').trim() != _filters.appKey!.trim()) return false;
      if (!_isEmptyFilter(_filters.adUnits) && !_adUnitMatches(row.adUnits, _filters.adUnits!)) return false;
      if (!_isEmptyFilter(_filters.country) && (row.country ?? '').trim().toUpperCase() != _filters.country!.trim().toUpperCase()) return false;
      if (!_isEmptyFilter(_filters.platform) && (row.platform ?? '').trim().toLowerCase() != _filters.platform!.trim().toLowerCase()) return false;
      return true;
    }).toList();
    _rawRows = filtered;
    _stats = DashboardRepository.statsFromRows(filtered);
    setState(() {});
  }

  bool _adUnitMatches(String? rowAdUnit, String filterAdUnit) {
    if (rowAdUnit == null) return false;
    final normalized = rowAdUnit.toLowerCase().replaceAll(' ', '');
    final f = filterAdUnit.toLowerCase().trim();
    return normalized.contains(f) || f.contains(normalized) ||
        (f == 'rewardedvideo' && normalized.contains('rewarded')) ||
        (f == 'offerwall' && normalized.contains('offer'));
  }

  Future<void> _load() async {
    if (_isCacheValid) {
      _applyFiltersFromCache();
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final full = await _repo.getStatsRawFull(_filters.startDateStr, _filters.endDateStr);
      if (_apps.isEmpty) {
        try {
          _apps = await _repo.getApplications();
        } catch (_) {}
      }
      if (!mounted) return;
      _cachedRawRows = full;
      _cachedStartDate = _filters.startDateStr;
      _cachedEndDate = _filters.endDateStr;
      _applyFiltersFromCache();
      setState(() => _loading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 365 * 2)),
      lastDate: now,
      initialDateRange: DateTimeRange(
        start: _filters.startDate,
        end: _filters.endDate,
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        _filters = _filters.copyWith(
          startDate: DateTime(picked.start.year, picked.start.month, picked.start.day),
          endDate: DateTime(picked.end.year, picked.end.month, picked.end.day),
          datePreset: DateRangePreset.custom,
        );
      });
      _load();
    }
  }

  void _applyPreset(DateRangePreset preset) {
    final now = DateTime.now();
    DateTime start;
    switch (preset) {
      case DateRangePreset.today:
      case DateRangePreset.yesterday:
        start = DateTime(now.year, now.month, now.day).subtract(preset == DateRangePreset.yesterday ? const Duration(days: 1) : Duration.zero);
        break;
      case DateRangePreset.last7:
        start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
        break;
      case DateRangePreset.last30:
        start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 29));
        break;
      case DateRangePreset.last90:
        start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 89));
        break;
      case DateRangePreset.custom:
        _pickDateRange();
        return;
    }
    final end = preset == DateRangePreset.yesterday
        ? start
        : DateTime(now.year, now.month, now.day);
    setState(() {
      _filters = _filters.copyWith(
        startDate: start,
        endDate: end,
        datePreset: preset,
      );
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.appName),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/credentials'),
            tooltip: 'Cambiar claves IronSource',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () {
          _cachedRawRows = [];
          _cachedStartDate = null;
          _cachedEndDate = null;
          return _load();
        },
        child: _loading && _stats == null
            ? const Center(child: CircularProgressIndicator())
            : _error != null && _stats == null
                ? _ErrorBody(message: _error!, onRetry: _load)
                : Stack(
                    children: [
                      SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildDateFilters(),
                            const SizedBox(height: 16),
                            if (_stats != null) ...[
                              _buildStatsGrid(_stats!),
                              const SizedBox(height: 24),
                              _buildRevenueChart(),
                              const SizedBox(height: 20),
                              _buildImpressionsChart(),
                              const SizedBox(height: 24),
                              _buildFiltersSection(),
                              const SizedBox(height: 20),
                              _buildCountriesSection(),
                              const SizedBox(height: 20),
                              _buildDataTable(),
                            ],
                          ],
                        ),
                      ),
                      if (_loading && _stats != null)
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: Material(
                            elevation: 2,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              color: Theme.of(context).colorScheme.primaryContainer,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Cargando datos…',
                                    style: Theme.of(context).textTheme.titleSmall,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
      ),
    );
  }

  Widget _buildDateFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _presetChip('Hoy', DateRangePreset.today),
          const SizedBox(width: 8),
          _presetChip('Ayer', DateRangePreset.yesterday),
          const SizedBox(width: 8),
          _presetChip('7 días', DateRangePreset.last7),
          const SizedBox(width: 8),
          _presetChip('30 días', DateRangePreset.last30),
          const SizedBox(width: 8),
          _presetChip('90 días', DateRangePreset.last90),
          const SizedBox(width: 8),
          ActionChip(
            label: const Text('Personalizado'),
            onPressed: _pickDateRange,
            avatar: const Icon(Icons.calendar_today, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _presetChip(String label, DateRangePreset preset) {
    final selected = _filters.datePreset == preset;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => _applyPreset(preset),
    );
  }

  Widget _buildStatsGrid(DashboardStats s) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossCount = constraints.maxWidth > 600 ? 3 : 2;
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossCount,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.4,
          children: [
            StatCard(
              title: 'Ingresos',
              value: formatMoney(s.revenue),
              icon: Icons.attach_money,
            ),
            StatCard(
              title: 'Impresiones',
              value: formatNumber(s.impressions),
              icon: Icons.visibility,
            ),
            StatCard(
              title: 'eCPM',
              value: formatMoney(s.ecpm),
              icon: Icons.trending_up,
            ),
            if (s.clicks != null)
              StatCard(
                title: 'Clicks',
                value: formatNumber(s.clicks!),
                icon: Icons.touch_app,
              ),
            if (s.completions != null)
              StatCard(
                title: 'Completados',
                value: formatNumber(s.completions!),
                icon: Icons.check_circle,
              ),
          ],
        );
      },
    );
  }

  Widget _buildRevenueChart() {
    final byDate = <String, double>{};
    for (final row in _rawRows) {
      final date = row.date ?? '';
      for (final d in row.data ?? []) {
        final r = (d['revenue'] is num) ? (d['revenue'] as num).toDouble() : 0.0;
        byDate[date] = (byDate[date] ?? 0) + r;
      }
    }
    final entries = byDate.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    if (entries.isEmpty) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: Text('Sin datos para el gráfico')),
        ),
      );
    }
    final maxY = entries.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    final minY = 0.0;
    final spots = entries.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.value)).toList();
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.show_chart, color: Theme.of(context).colorScheme.primary, size: 22),
                const SizedBox(width: 8),
                Text(
                  'Ingresos por fecha',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 220,
              child: LineChart(
                LineChartData(
                  minY: minY,
                  maxY: maxY <= 0 ? 1 : (maxY * 1.1),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (v) => FlLine(
                      color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 42,
                        getTitlesWidget: (value, meta) => Text(
                          formatMoneyChart(value),
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        getTitlesWidget: (value, meta) {
                          final i = value.toInt();
                          if (i >= 0 && i < entries.length) {
                            final dateStr = entries[i].key;
                            final label = dateStr.length >= 10 ? dateStr.substring(5, 10) : dateStr;
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                label,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
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
                      isCurved: true,
                      barWidth: 2.5,
                      color: Theme.of(context).colorScheme.primary,
                      dotData: FlDotData(
                        show: spots.length <= 20,
                        getDotPainter: (spot, percent, barData, index) =>
                            FlDotCirclePainter(
                              radius: 3,
                              color: Theme.of(context).colorScheme.primary,
                              strokeWidth: 0,
                            ),
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Gráfica de impresiones por fecha. Con muchos días (ej. 90) agrupa por semana para que no se encime.
  Widget _buildImpressionsChart() {
    final byDate = <String, int>{};
    for (final row in _rawRows) {
      final date = row.date ?? '';
      for (final d in row.data ?? []) {
        final imp = (d['impressions'] is num) ? (d['impressions'] as num).toInt() : 0;
        byDate[date] = (byDate[date] ?? 0) + imp;
      }
    }
    var entries = byDate.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    if (entries.isEmpty) return const SizedBox.shrink();

    // Con más de 21 días, agrupar por semana para que no se encimen las barras
    const maxBars = 21;
    if (entries.length > maxBars) {
      final byWeek = <String, int>{};
      for (final e in entries) {
        final d = DateTime.tryParse(e.key);
        if (d != null) {
          final weekStart = d.subtract(Duration(days: d.weekday - 1));
          final key = '${weekStart.year}-${weekStart.month.toString().padLeft(2, '0')}-${weekStart.day.toString().padLeft(2, '0')}';
          byWeek[key] = (byWeek[key] ?? 0) + e.value;
        }
      }
      entries = byWeek.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    }

    final maxY = entries.map((e) => e.value.toDouble()).reduce((a, b) => a > b ? a : b);
    final barCount = entries.length;
    final barWidth = (barCount > 14) ? 8.0 : (barCount > 7 ? 14.0 : 20.0);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.visibility, color: Theme.of(context).colorScheme.secondary, size: 22),
                const SizedBox(width: 8),
                Text(
                  barCount <= maxBars ? 'Impresiones por fecha' : 'Impresiones por semana',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 180,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxY <= 0 ? 1 : (maxY * 1.1),
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => Theme.of(context).colorScheme.inverseSurface,
                      tooltipBorderRadius: BorderRadius.circular(8),
                      tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final dateLabel = groupIndex >= 0 && groupIndex < entries.length
                            ? entries[groupIndex].key
                            : '';
                        return BarTooltipItem(
                          '${formatNumberChart(rod.toY.toInt())}\n$dateLabel',
                          TextStyle(
                            color: Theme.of(context).colorScheme.onInverseSurface,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) => Text(
                          formatNumberChart(value.toInt()),
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        interval: barCount > 14 ? (barCount / 7).ceilToDouble() : 1,
                        getTitlesWidget: (value, meta) {
                          final i = value.toInt();
                          if (i >= 0 && i < entries.length) {
                            final label = entries[i].key.length >= 10
                                ? entries[i].key.substring(5, 10)
                                : entries[i].key;
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                label,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                                overflow: TextOverflow.ellipsis,
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
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (v) => FlLine(
                      color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: entries.asMap().entries.map((e) {
                    final value = e.value.value.toDouble();
                    return BarChartGroupData(
                      x: e.key,
                      barRods: [
                        BarChartRodData(
                          toY: value,
                          color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.8),
                          width: barWidth,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        ),
                      ],
                      showingTooltipIndicators: [],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Lista de países con ingresos (nombres con formatCountry).
  List<Map<String, dynamic>> _aggregateByCountry() {
    final byCountry = <String, Map<String, dynamic>>{};
    for (final row in _rawRows) {
      final countryKey = (row.country ?? '').trim().isEmpty ? '__all__' : (row.country!.trim().toUpperCase());
      for (final d in row.data ?? []) {
        final rev = (d['revenue'] is num) ? (d['revenue'] as num).toDouble() : 0.0;
        final imp = (d['impressions'] is num) ? (d['impressions'] as num).toInt() : 0;
        if (!byCountry.containsKey(countryKey)) {
          byCountry[countryKey] = {'revenue': 0.0, 'impressions': 0};
        }
        byCountry[countryKey]!['revenue'] = (byCountry[countryKey]!['revenue'] as num) + rev;
        byCountry[countryKey]!['impressions'] = (byCountry[countryKey]!['impressions'] as int) + imp;
      }
    }
    return byCountry.entries
        .map((e) => {
              'countryCode': e.key == '__all__' ? null : e.key,
              'revenue': (e.value['revenue'] as num).toDouble(),
              'impressions': e.value['impressions'] as int,
            })
        .toList()
      ..sort((a, b) => (b['revenue'] as num).compareTo(a['revenue'] as num));
  }

  Widget _buildCountriesSection() {
    final byCountry = _aggregateByCountry();
    if (byCountry.isEmpty) return const SizedBox.shrink();
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.public, color: Theme.of(context).colorScheme.tertiary, size: 22),
                const SizedBox(width: 8),
                Text(
                  'Por país',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...byCountry.take(12).map((r) {
              final code = r['countryCode'] as String?;
              final name = formatCountry(code);
              final rev = (r['revenue'] as num).toDouble();
              final imp = r['impressions'] as int;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        name,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        formatMoney(rev),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        textAlign: TextAlign.end,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      formatNumber(imp),
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.end,
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  List<String?> get _uniqueCountryCodes {
    final set = <String?>{};
    for (final row in _cachedRawRows) {
      final c = row.country?.trim();
      if (c == null || c.isEmpty) {
        set.add(null);
      } else {
        set.add(c);
      }
    }
    return set.toList()..sort((a, b) => (a ?? '').compareTo(b ?? ''));
  }

  Widget _buildFiltersSection() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.filter_list, color: Theme.of(context).colorScheme.primary, size: 22),
                const SizedBox(width: 8),
                Text(
                  'Filtros',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _filters.appKey ?? '',
              decoration: InputDecoration(
                labelText: 'App',
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: [
                const DropdownMenuItem(value: '', child: Text('Todas')),
                ..._apps.where((a) => (a.appKey ?? '').isNotEmpty).map((a) => DropdownMenuItem<String>(
                      value: a.appKey!,
                      child: Text('${a.appName ?? a.appKey} (${a.platform ?? ''})'),
                    )),
              ],
              onChanged: (v) {
                setState(() => _filters = _filters.copyWith(appKey: (v == null || v.isEmpty) ? '' : v));
                _applyFiltersFromCache();
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _filters.adUnits ?? '',
              decoration: InputDecoration(
                labelText: 'Tipo de anuncio',
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: const [
                DropdownMenuItem(value: '', child: Text('Todos')),
                DropdownMenuItem(value: 'rewardedVideo', child: Text('Rewarded Video')),
                DropdownMenuItem(value: 'interstitial', child: Text('Interstitial')),
                DropdownMenuItem(value: 'banner', child: Text('Banner')),
                DropdownMenuItem(value: 'offerWall', child: Text('Offerwall')),
              ],
              onChanged: (v) {
                setState(() => _filters = _filters.copyWith(adUnits: (v == null || v.isEmpty) ? '' : v));
                _applyFiltersFromCache();
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _filters.platform ?? '',
              decoration: InputDecoration(
                labelText: 'Plataforma',
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: const [
                DropdownMenuItem(value: '', child: Text('Todas')),
                DropdownMenuItem(value: 'android', child: Text('Android')),
                DropdownMenuItem(value: 'ios', child: Text('iOS')),
              ],
              onChanged: (v) {
                setState(() => _filters = _filters.copyWith(platform: (v == null || v.isEmpty) ? '' : v));
                _applyFiltersFromCache();
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _filters.country ?? '',
              decoration: InputDecoration(
                labelText: 'País',
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: [
                const DropdownMenuItem(value: '', child: Text('Todos')),
                ..._uniqueCountryCodes
                    .whereType<String>()
                    .where((c) => c.isNotEmpty)
                    .map((code) => DropdownMenuItem<String>(
                          value: code,
                          child: Text(formatCountry(code)),
                        )),
              ],
              onChanged: (v) {
                setState(() => _filters = _filters.copyWith(country: (v == null || v.isEmpty) ? '' : v));
                _applyFiltersFromCache();
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Agrupa por fecha: una fila por día con totales (menos filas, más claro).
  List<Map<String, dynamic>> _aggregateRowsByDate() {
    final byDate = <String, Map<String, dynamic>>{};
    for (final row in _rawRows) {
      final date = row.date ?? '';
      if (date.isEmpty) continue;
      for (final d in row.data ?? []) {
        final rev = (d['revenue'] is num) ? (d['revenue'] as num).toDouble() : 0.0;
        final imp = (d['impressions'] is num) ? (d['impressions'] as num).toInt() : 0;
        final clk = (d['clicks'] is num) ? (d['clicks'] as num).toInt() : 0;
        final comp = (d['completions'] is num) ? (d['completions'] as num).toInt() : 0;
        if (!byDate.containsKey(date)) {
          byDate[date] = {'revenue': 0.0, 'impressions': 0, 'clicks': 0, 'completions': 0};
        }
        final acc = byDate[date]!;
        acc['revenue'] = (acc['revenue'] as num) + rev;
        acc['impressions'] = (acc['impressions'] as int) + imp;
        acc['clicks'] = (acc['clicks'] as int) + clk;
        acc['completions'] = (acc['completions'] as int) + comp;
      }
    }
    final list = byDate.entries.map((e) {
      final v = e.value;
      final rev = (v['revenue'] as num).toDouble();
      final imp = v['impressions'] as int;
      final clk = v['clicks'] as int;
      final comp = v['completions'] as int;
      return <String, dynamic>{
        'date': e.key,
        'revenue': rev,
        'impressions': imp,
        'eCPM': imp > 0 ? (rev / imp) * 1000 : 0.0,
        'clicks': clk,
        'completions': comp,
      };
    }).toList();
    list.sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));
    return list;
  }

  Widget _buildDataTable() {
    if (_rawRows.isEmpty) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: Text('Sin datos para la tabla')),
        ),
      );
    }
    final aggregated = _aggregateRowsByDate();
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.table_chart, color: Theme.of(context).colorScheme.primary, size: 22),
                const SizedBox(width: 8),
                Text(
                  'Totales por día',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(
                  Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                ),
                dataRowColor: WidgetStateProperty.resolveWith((states) {
                  return null;
                }),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                ),
                columns: const [
                  DataColumn(label: Text('Fecha')),
                  DataColumn(label: Text('Ingresos'), numeric: true),
                  DataColumn(label: Text('Impresiones'), numeric: true),
                  DataColumn(label: Text('eCPM'), numeric: true),
                  DataColumn(label: Text('Clicks'), numeric: true),
                  DataColumn(label: Text('Completados'), numeric: true),
                ],
                rows: aggregated.map((r) {
                  final revenue = (r['revenue'] as num).toDouble();
                  final impressions = r['impressions'] as int;
                  final ecpm = (r['eCPM'] as num).toDouble();
                  final clicks = r['clicks'] as int;
                  final completions = r['completions'] as int;
                  final dateStr = r['date'] as String;
                  return DataRow(
                    cells: [
                      DataCell(Tooltip(message: dateStr, child: Text(dateStr))),
                      DataCell(Tooltip(
                        message: formatMoney(revenue),
                        child: Text(formatMoney(revenue)),
                      )),
                      DataCell(Tooltip(
                        message: formatNumber(impressions),
                        child: Text(formatNumber(impressions)),
                      )),
                      DataCell(Tooltip(
                        message: formatMoney(ecpm),
                        child: Text(formatMoney(ecpm)),
                      )),
                      DataCell(Tooltip(
                        message: formatNumber(clicks),
                        child: Text(formatNumber(clicks)),
                      )),
                      DataCell(Tooltip(
                        message: formatNumber(completions),
                        child: Text(formatNumber(completions)),
                      )),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
