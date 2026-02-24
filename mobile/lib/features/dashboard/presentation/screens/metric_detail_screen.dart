import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/app_strings.dart';
import '../../../../core/locale_notifier.dart';
import '../../../../core/theme/theme_mode_notifier.dart';
import '../../../../data/credentials/credentials_repository.dart';
import '../../../../data/ironsource/ironsource_api_client.dart';
import '../../../../shared/utils/formatters.dart';
import '../../../../shared/widgets/multi_select_dialog.dart';
import '../../../glossary/glossary_data.dart';
import '../../data/dashboard_repository.dart';
import '../../domain/dashboard_filters.dart';
import '../../domain/dashboard_stats.dart';

double _revNum(Object? v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0;
  return 0;
}

class MetricDetailScreen extends StatefulWidget {
  const MetricDetailScreen({super.key, required this.metricId});

  final String metricId;

  @override
  State<MetricDetailScreen> createState() => _MetricDetailScreenState();
}

class _MetricDetailScreenState extends State<MetricDetailScreen> {
  final DashboardRepository _repo = DashboardRepository();
  final CredentialsRepository _credentials = CredentialsRepository();

  DashboardFilters _filters = DashboardFilters.last7Days();
  List<IronSourceStatsRow> _rawRows = [];
  List<IronSourceApp> _apps = [];
  List<IronSourceStatsRow> _filterMetadataRows = [];
  bool _loading = true;
  String? _error;

  List<IronSourceStatsRow> _cachedRawRows = [];
  String? _cachedStartDate;
  String? _cachedEndDate;
  String? _cachedFilterKey;
  DashboardStats? _prevStats;

  @override
  void initState() {
    super.initState();
    ThemeModeNotifier.valueNotifier.addListener(_onThemeChanged);
    _loadSavedFiltersAndCheckCredentials();
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    ThemeModeNotifier.valueNotifier.removeListener(_onThemeChanged);
    super.dispose();
  }

  Future<void> _loadSavedFiltersAndCheckCredentials() async {
    final saved = await DashboardFilters.loadDashboard();
    if (!mounted) return;
    setState(() => _filters = saved);
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
      _cachedFilterKey == _filterKey;

  String get _filterKey =>
      '${_filters.appKeys?.join(',') ?? ''}|${_filters.countries?.join(',') ?? ''}|${_filters.adUnits?.join(',') ?? ''}|${_filters.platforms?.join(',') ?? ''}';

  void _applyFiltersFromCache() {
    _rawRows = _cachedRawRows;
    setState(() {});
  }

  Future<void> _load() async {
    if (_isCacheValid) {
      _applyFiltersFromCache();
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _rawRows = [];
      _cachedRawRows = [];
    });
    try {
      final dateFilters = DashboardFilters(
        startDate: _filters.startDate,
        endDate: _filters.endDate,
        datePreset: _filters.datePreset,
      );
      final full = await _repo.getStatsRaw(_filters);
      final metadataFuture = _repo.getFilterMetadata(dateFilters);
      if (_apps.isEmpty) {
        try { _apps = await _repo.getApplications(); } catch (_) {}
      }
      if (!mounted) return;
      _cachedRawRows = full;
      _cachedStartDate = _filters.startDateStr;
      _cachedEndDate = _filters.endDateStr;
      _cachedFilterKey = _filterKey;
      _applyFiltersFromCache();
      try {
        _filterMetadataRows = await metadataFuture;
      } catch (_) {}
      try {
        final prev = await _repo.getPreviousPeriodStats(_filters);
        if (mounted) _prevStats = prev;
      } catch (_) {}
      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = _isNetworkError(e.toString())
              ? AppStrings.t('no_internet', LocaleNotifier.current)
              : e.toString();
          _loading = false;
        });
      }
    }
  }

  static bool _isNetworkError(String error) {
    final lower = error.toLowerCase();
    return lower.contains('socketexception') ||
        lower.contains('failed host lookup') ||
        lower.contains('connection refused') ||
        lower.contains('connection timed out') ||
        lower.contains('network is unreachable') ||
        lower.contains('no internet');
  }

  static bool _isKeysError(String? error) {
    if (error == null || error.isEmpty) return false;
    final lower = error.toLowerCase();
    return lower.contains('secret') ||
        lower.contains('refresh token') ||
        lower.contains('bearer') ||
        lower.contains('401') ||
        lower.contains('403') ||
        lower.contains('unauthorized') ||
        lower.contains('invalid credentials') ||
        lower.contains('configura secret') ||
        lower.contains('token vacío');
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020, 1, 1),
      lastDate: now,
      initialDateRange: DateTimeRange(start: _filters.startDate, end: _filters.endDate),
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
    final end = preset == DateRangePreset.yesterday ? start : DateTime(now.year, now.month, now.day);
    setState(() {
      _filters = _filters.copyWith(startDate: start, endDate: end, datePreset: preset);
    });
    _load();
  }

  /// Total de la métrica actual con los filtros aplicados (para tasas devuelve promedio).
  double _totalValueForMetric() {
    double total = 0;
    int totalImpressions = 0;
    double totalRevenue = 0;
    int rateCount = 0;
    for (final row in _rawRows) {
      for (final d in row.data ?? []) {
        switch (widget.metricId) {
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
    if (widget.metricId == 'revenue') return total;
    if (widget.metricId == 'ecpm' && totalImpressions > 0) return (totalRevenue / totalImpressions) * 1000;
    if (rateCount > 0) return total / rateCount;
    return total;
  }

  /// Valores por fecha para la métrica actual.
  List<MapEntry<String, double>> _entriesByDate() {
    final byDate = <String, double>{};
    for (final row in _rawRows) {
      final date = row.date ?? '';
      if (date.isEmpty) continue;
      for (final d in row.data ?? []) {
        double v = 0;
        switch (widget.metricId) {
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

  /// Mínimo intervalo "nice" >= [minInterval] (máx. 8 etiquetas en el eje Y).
  static double _niceIntervalAtLeast(double minInterval) {
    if (minInterval <= 0) return 1;
    const candidates = [0.01, 0.02, 0.05, 0.1, 0.2, 0.25, 0.5, 1.0, 2.0, 5.0, 10.0, 20.0, 50.0, 100.0];
    for (final c in candidates) {
      if (c >= minInterval) return c;
    }
    return (minInterval / 50).ceilToDouble() * 50;
  }

  String _formatChartValue(double value) {
    switch (widget.metricId) {
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
    switch (_filters.datePreset) {
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

  double? _prevValueForMetric() {
    final prev = _prevStats;
    if (prev == null) return null;
    switch (widget.metricId) {
      case 'revenue':
        return prev.revenue > 0 ? prev.revenue.toDouble() : null;
      case 'impressions':
        return prev.impressions > 0 ? prev.impressions.toDouble() : null;
      case 'ecpm':
        return prev.ecpm > 0 ? prev.ecpm : null;
      default:
        return null;
    }
  }

  Widget _buildMetricHeroCard() {
    final locale = LocaleNotifier.current;
    final entry = getGlossaryEntry(widget.metricId);
    final title = entry != null ? getGlossaryTitle(entry.id, locale) : widget.metricId;
    final value = _totalValueForMetric();
    final prevValue = _prevValueForMetric();
    final showCompare = _filters.datePreset != DateRangePreset.custom &&
        prevValue != null &&
        prevValue > 0;
    double? pct;
    if (showCompare) {
      final pv = prevValue;
      if (pv > 0) pct = ((value - pv) / pv) * 100;
    }
    final prevLabel = _metricPrevPeriodLabel(locale);
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
              const Color(0xFF5BA3E8).withValues(alpha: 0.12),
              cs.tertiary.withValues(alpha: 0.06),
            ],
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
                color: cs.onSurfaceVariant.withValues(alpha: 0.85),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatChartValue(value),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: const Color(0xFF5BA3E8),
              ),
            ),
            if (pct != null && prevLabel.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                '${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(1)}% $prevLabel',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: pct >= 0 ? Colors.green : Colors.red,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _goBack() async {
    await _saveFilters();
    if (!mounted) return;
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final locale = LocaleNotifier.current;
    final entry = getGlossaryEntry(widget.metricId);
    final title = entry != null ? getGlossaryTitle(entry.id, locale) : widget.metricId;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _goBack();
      },
      child: Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(context).colorScheme.surface,
                const Color(0xFF5BA3E8).withValues(alpha: 0.12),
              ],
            ),
          ),
        ),
        title: Text(title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _goBack,
        ),
        actions: const [],
      ),
      body: _loading && _rawRows.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _rawRows.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline_rounded,
                          size: 56,
                          color: Theme.of(context).colorScheme.error.withValues(alpha: 0.9),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _MetricDetailScreenState._isKeysError(_error)
                              ? AppStrings.t('invalid_keys', locale)
                              : _error!,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          onPressed: _load,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () {
                    _cachedRawRows = [];
                    _cachedStartDate = null;
                    _cachedEndDate = null;
                    return _load();
                  },
                  child: Stack(
                    children: [
                      SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 800),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildDateChips(),
                                const SizedBox(height: 16),
                                _buildFiltersCard(),
                                const SizedBox(height: 20),
                                _buildMetricHeroCard(),
                                const SizedBox(height: 20),
                                _buildChart(),
                                if (entry != null) ...[
                                  const SizedBox(height: 20),
                                  _buildDescriptionCard(entry),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (_loading)
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: Material(
                            elevation: 0,
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
                                    'Cargando…',
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
      ),
    );
  }

  Widget _buildDateChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _chip('Hoy', DateRangePreset.today),
          const SizedBox(width: 8),
          _chip('Ayer', DateRangePreset.yesterday),
          const SizedBox(width: 8),
          _chip('7 días', DateRangePreset.last7),
          const SizedBox(width: 8),
          _chip('30 días', DateRangePreset.last30),
          const SizedBox(width: 8),
          _chip('90 días', DateRangePreset.last90),
          const SizedBox(width: 8),
          FilterChip(
            label: Text(AppStrings.t('filter_custom', LocaleNotifier.current)),
            selected: _filters.datePreset == DateRangePreset.custom,
            onSelected: (_) => _pickDateRange(),
            avatar: const Icon(Icons.calendar_today, size: 18),
            selectedColor: Theme.of(context).colorScheme.primaryContainer,
            checkmarkColor: Theme.of(context).colorScheme.primary,
            showCheckmark: true,
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, DateRangePreset preset) {
    final selected = _filters.datePreset == preset;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => _applyPreset(preset),
      selectedColor: Theme.of(context).colorScheme.primaryContainer,
      checkmarkColor: Theme.of(context).colorScheme.primary,
      showCheckmark: true,
    );
  }

  Widget _buildFiltersCard() {
    final width = MediaQuery.of(context).size.width;
    final isWide = width > 600;
    final compact = width < 400;
    final dropWidth = compact ? 110.0 : (isWide ? 160.0 : double.infinity);
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
              cs.primary.withValues(alpha: 0.12),
              cs.tertiary.withValues(alpha: 0.06),
            ],
          ),
        ),
        child: Padding(
        padding: EdgeInsets.all(compact ? 10 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.filter_list, size: compact ? 16 : 18, color: cs.primary),
                ),
                SizedBox(width: compact ? 8 : 10),
                Text(AppStrings.t('filters', LocaleNotifier.current), style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
            SizedBox(height: compact ? 8.0 : 12.0),
            if (isWide)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(width: dropWidth, child: _appDropdown(compact)),
                    SizedBox(width: compact ? 6.0 : 12.0),
                    SizedBox(width: dropWidth, child: _adUnitDropdown(compact)),
                    SizedBox(width: compact ? 6.0 : 12.0),
                    SizedBox(width: compact ? 100.0 : 120.0, child: _platformDropdown(compact)),
                    SizedBox(width: compact ? 6.0 : 12.0),
                    SizedBox(width: dropWidth, child: _countryDropdown(compact)),
                  ],
                ),
              )
            else
              LayoutBuilder(
                builder: (_, c) {
                  final gap = compact ? 8.0 : 12.0;
                  final half = ((c.maxWidth - gap) / 2).clamp(80.0, double.infinity);
                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: [
                      SizedBox(width: half, child: _appDropdown(compact)),
                      SizedBox(width: half, child: _adUnitDropdown(compact)),
                      SizedBox(width: half, child: _platformDropdown(compact)),
                      SizedBox(width: half, child: _countryDropdown(compact)),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    ),
    );
  }

  Future<void> _saveFilters() async {
    await DashboardFilters.saveDashboard(_filters);
  }

  void _onFiltersChanged() {
    _load(); // Refetch: filtros se envían a la API
  }

  Widget _appDropdown([bool compact = false]) {
    final apps = _apps.where((a) => (a.appKey ?? '').isNotEmpty).toList();
    final selected = _filters.appKeys ?? [];
    final selectedSet = selected.toSet();
    final optsCount = apps.length;
    final allSelected = selected.isNotEmpty && optsCount > 0 &&
        apps.every((a) => selectedSet.contains(a.appKey));
    final lm = LocaleNotifier.current;
    String valueLabel;
    if (selected.isEmpty || allSelected) {
      valueLabel = AppStrings.t('all_apps', lm);
    } else if (selected.length == 1) {
      final a = apps.cast<IronSourceApp?>().firstWhere((x) => x?.appKey == selected.single, orElse: () => null);
      valueLabel = a != null ? '${a.appName ?? a.appKey} (${a.platform ?? ''})' : selected.single;
    } else {
      valueLabel = '${selected.length} ${AppStrings.t('apps_count', lm)}';
    }
    return _buildFilterChip(label: AppStrings.t('app_filter', lm), valueLabel: valueLabel, compact: compact, onTap: () async {
      final options = apps.map((a) => '${a.appKey}|${a.platform ?? ''}').toList();
      final labels = apps.map((a) => '${a.appName ?? a.appKey} (${a.platform ?? ''})').toList();
      final allSelectedForDialog = selected.isEmpty || (optsCount > 0 && apps.every((a) => selectedSet.contains(a.appKey)));
      final initialSelected = allSelectedForDialog
          ? options.toSet()
          : apps.where((a) => selectedSet.contains(a.appKey)).map((a) => '${a.appKey}|${a.platform ?? ''}').toSet();
      final chosen = await _showMultiSelect(
        title: AppStrings.t('app_filter', lm),
        options: options,
        labels: labels,
        selected: initialSelected,
      );
      if (chosen != null && mounted) {
        final all = chosen.isEmpty || (options.isNotEmpty && chosen.length >= options.length);
        final appKeys = all ? null : chosen.map((s) => s.split('|').first).toSet().toList();
        setState(() => _filters = _filters.copyWith(appKeys: appKeys, clearAppKeys: all));
        _onFiltersChanged();
      }
    });
  }

  Widget _adUnitDropdown([bool compact = false]) {
    const options = ['rewardedVideo', 'interstitial', 'banner', 'offerWall'];
    final lm = LocaleNotifier.current;
    final labels = [AppStrings.t('rewarded_video', lm), AppStrings.t('interstitial', lm), AppStrings.t('banner', lm), AppStrings.t('offerwall', lm)];
    final selected = _filters.adUnits ?? [];
    final label = selected.isEmpty || selected.length >= options.length ? AppStrings.t('all', lm) : (selected.length == 1 ? labels[options.indexOf(selected.single)] : '${selected.length} ${AppStrings.t('ad_types_count', lm)}');
    return _buildFilterChip(label: compact ? AppStrings.t('filter_ad_compact', lm) : AppStrings.t('filter_ad_type', lm), valueLabel: label, compact: compact, onTap: () async {
      final allSelected = selected.isEmpty || selected.length >= options.length;
      final chosen = await _showMultiSelect(title: AppStrings.t('filter_ad_type', lm), options: options, labels: labels, selected: allSelected ? options.toSet() : selected.toSet());
      if (chosen != null && mounted) {
        final all = chosen.isEmpty || chosen.length >= options.length;
        setState(() => _filters = _filters.copyWith(adUnits: all ? null : chosen, clearAdUnits: all));
        _onFiltersChanged();
      }
    });
  }

  Widget _platformDropdown([bool compact = false]) {
    const options = ['android', 'ios'];
    const labels = ['Android', 'iOS'];
    final selected = _filters.platforms ?? [];
    final lp = LocaleNotifier.current;
    final label = selected.isEmpty || selected.length >= options.length ? AppStrings.t('all_platforms', lp) : (selected.length == 1 ? labels[options.indexOf(selected.single)] : '${selected.length} ${AppStrings.t('platforms_count', lp)}');
    return _buildFilterChip(label: compact ? AppStrings.t('filter_os_compact', lp) : AppStrings.t('filter_platform', lp), valueLabel: label, compact: compact, onTap: () async {
      final allSelected = selected.isEmpty || selected.length >= 2;
      final chosen = await _showMultiSelect(title: AppStrings.t('filter_platform', lp), options: options, labels: labels, selected: allSelected ? options.toSet() : selected.toSet());
      if (chosen != null && mounted) {
        final all = chosen.isEmpty || chosen.length >= 2;
        setState(() => _filters = _filters.copyWith(platforms: all ? null : chosen, clearPlatforms: all));
        _onFiltersChanged();
      }
    });
  }

  /// Lista unificada: countryCodesForFilter + países que aparecen en los datos.
  /// Con breakdowns: 'date' las filas no tienen country; usamos _filterMetadataRows.
  List<String> get _countryOptions {
    final base = countryCodesForFilter.toSet();
    for (final row in _filterMetadataRows) {
      final c = (row.country ?? '').trim().toUpperCase();
      if (c.isNotEmpty) base.add(c);
    }
    return base.toList()..sort();
  }

  Widget _countryDropdown([bool compact = false]) {
    final options = _countryOptions;
    final selected = _filters.countries ?? [];
    final allSelected = selected.isNotEmpty && options.isNotEmpty &&
        selected.toSet().containsAll(options) && options.toSet().containsAll(selected);
    final l = LocaleNotifier.current;
    final label = selected.isEmpty || allSelected ? AppStrings.t('all', l) : (selected.length == 1 ? formatCountry(selected.single, l) : '${selected.length} ${AppStrings.t('countries_count', l)}');
    return _buildFilterChip(label: AppStrings.t('filter_country', l), valueLabel: label, compact: compact, onTap: () async {
      final allSelectedForDialog = selected.isEmpty || allSelected;
      final chosen = await _showMultiSelect(title: AppStrings.t('filter_country', l), options: options, labels: options.map((c) => formatCountry(c, l)).toList(), selected: allSelectedForDialog ? options.toSet() : selected.toSet());
      if (chosen != null && mounted) {
        final all = chosen.isEmpty || chosen.length >= options.length;
        setState(() => _filters = _filters.copyWith(countries: all ? null : chosen, clearCountries: all));
        _onFiltersChanged();
      }
    });
  }

  Widget _buildFilterChip({required String label, required String valueLabel, required bool compact, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(compact ? 8 : 12),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 14, vertical: compact ? 10 : 12),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(compact ? 8 : 12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 11,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Expanded(child: Text(valueLabel, overflow: TextOverflow.ellipsis, maxLines: 1, style: Theme.of(context).textTheme.bodyMedium)),
                const Icon(Icons.arrow_drop_down, size: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<List<String>?> _showMultiSelect({
    required String title,
    required List<String> options,
    required List<String> labels,
    required Set<String> selected,
  }) async {
    return showDialog<List<String>>(
      context: context,
      builder: (ctx) => MultiSelectDialog(
        title: title,
        options: options,
        labels: labels,
        selected: selected,
      ),
    );
  }

  Widget _buildChart() {
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

    final dataMaxY = entries.isEmpty ? 1.0 : entries.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    final minY = 0.0;
    final range = (dataMaxY - minY).clamp(0.01, double.infinity);
    final yInterval = _niceIntervalAtLeast(range / 7);
    final numSteps = (range / yInterval).ceil().clamp(1, 7);
    final maxY = minY + yInterval * numSteps;
    final spots = entries.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.value)).toList();
    final entry = getGlossaryEntry(widget.metricId);
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
                if (entry != null)
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF5BA3E8).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(entry.icon, color: const Color(0xFF5BA3E8), size: 20),
                  ),
                const SizedBox(width: 10),
                Text(
                  entry != null ? getGlossaryTitle(entry.id, LocaleNotifier.current) : widget.metricId,
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

  Widget _buildDescriptionCard(GlossaryEntry entry) {
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
