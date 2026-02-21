import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/credentials_updated_notifier.dart';
import '../../../../core/l10n/app_strings.dart';
import '../../../../core/locale_notifier.dart';
import '../../../../core/theme/theme_mode_notifier.dart';
import '../../../../data/credentials/credentials_repository.dart';
import '../../../../data/ironsource/ironsource_api_client.dart';
import '../../../../shared/utils/formatters.dart';
import '../../../../shared/widgets/multi_select_dialog.dart';
import '../../../../shared/widgets/stat_card.dart';
import '../../data/dashboard_repository.dart';
import '../../domain/dashboard_filters.dart';
import '../../domain/dashboard_stats.dart';

double _rev(Map<String, dynamic> d) => (d['revenue'] is num) ? (d['revenue'] as num).toDouble() : 0;

/// metricId para navegar a la pantalla de detalle de cada métrica.
const Map<String, String> _statCardMetricIds = {
  'Ingresos': 'revenue',
  'Impresiones': 'impressions',
  'eCPM': 'ecpm',
  'Clicks': 'clicks',
  'Completados': 'completions',
  'Fill rate': 'fill_rate',
  'Completion rate': 'completion_rate',
  'Revenue/completion': 'revenue_per_completion',
  'CTR': 'ctr',
  'App requests': 'app_requests',
  'DAU': 'dau',
  'Sesiones': 'sessions',
};

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
  List<IronSourceStatsRow> _filterMetadataRows = [];
  bool _loading = true;
  String? _error;

  // Cache: por fechas + filtros (se envían a la API)
  List<IronSourceStatsRow> _cachedRawRows = [];
  String? _cachedStartDate;
  String? _cachedEndDate;
  String? _cachedFilterKey;

  @override
  void initState() {
    super.initState();
    CredentialsUpdatedNotifier.instance.addListener(_onCredentialsUpdated);
    ThemeModeNotifier.valueNotifier.addListener(_onThemeChanged);
    _loadSavedFiltersAndCheckCredentials();
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadSavedFiltersAndCheckCredentials() async {
    if (mounted) {
      setState(() => _filters = DashboardFilters.last7Days());
      await _checkCredentials();
    }
  }

  @override
  void dispose() {
    ThemeModeNotifier.valueNotifier.removeListener(_onThemeChanged);
    CredentialsUpdatedNotifier.instance.removeListener(_onCredentialsUpdated);
    super.dispose();
  }

  void _onCredentialsUpdated() {
    if (!mounted) return;
    _cachedRawRows = [];
    _cachedStartDate = null;
    _cachedEndDate = null;
    _load();
  }

  void _onFiltersChanged() {
    _load(); // Refetch: filtros se envían a la API
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

  /// Cache válido si fechas y filtros coinciden (los filtros se envían a la API).
  bool get _isCacheValid =>
      _cachedStartDate == _filters.startDateStr &&
      _cachedEndDate == _filters.endDateStr &&
      _cachedFilterKey == _filterKey &&
      _cachedRawRows.isNotEmpty;

  String get _filterKey =>
      '${_filters.appKeys?.join(',') ?? ''}|${_filters.countries?.join(',') ?? ''}|${_filters.adUnits?.join(',') ?? ''}|${_filters.platforms?.join(',') ?? ''}';

  /// Con breakdowns: 'date' los filtros se envían a la API; no hay filtrado client-side.
  void _applyFiltersFromCache() {
    if (_cachedRawRows.isEmpty) return;
    _rawRows = _cachedRawRows;
    _stats = DashboardRepository.statsFromRows(_cachedRawRows);
    setState(() {});
  }

  Future<void> _saveFilters() async {
    await DashboardFilters.saveDashboard(_filters);
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
      final dateFilters = DashboardFilters(
        startDate: _filters.startDate,
        endDate: _filters.endDate,
        datePreset: _filters.datePreset,
      );
      final full = await _repo.getStatsRaw(_filters);
      final metadataFuture = _repo.getFilterMetadata(dateFilters);
      if (_apps.isEmpty) {
        try {
          _apps = await _repo.getApplications();
        } catch (_) {}
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
      if (!mounted) return;
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

  static bool _isKeysError(String? error) {
    if (error == null || error.isEmpty) return false;
    final lower = error.toLowerCase();
    return lower.contains('secret') ||
        lower.contains('refresh token') ||
        lower.contains('bearer') ||
        lower.contains('auth') ||
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
    final locale = LocaleNotifier.current;
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(context).colorScheme.surface,
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
              ],
            ),
          ),
        ),
        leading: IconButton(
          icon: Icon(
            ThemeModeNotifier.current == ThemeMode.light ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
          ),
          onPressed: () {
            ThemeModeNotifier.set(
              ThemeModeNotifier.current == ThemeMode.light ? ThemeMode.dark : ThemeMode.light,
            );
          },
          tooltip: ThemeModeNotifier.current == ThemeMode.light ? AppStrings.t('dark_mode', locale) : AppStrings.t('light_mode', locale),
        ),
        title: Text(AppStrings.t('dashboard_tab', LocaleNotifier.current)),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu_book_outlined),
            onPressed: () => context.push('/glossary'),
            tooltip: AppStrings.t('glossary_tooltip', locale),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/credentials'),
            tooltip: AppStrings.t('settings_tooltip', locale),
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
                ? _ErrorBody(
                    message: _DashboardScreenState._isKeysError(_error)
                        ? AppStrings.t('invalid_keys', locale)
                        : _error!,
                    onRetry: _load,
                  )
                : Stack(
                    children: [
                      SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1200),
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final padding = constraints.maxWidth > 900 ? 24.0 : (constraints.maxWidth > 600 ? 20.0 : 12.0);
                                return Padding(
                                  padding: EdgeInsets.symmetric(horizontal: padding),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      _buildDateFilters(),
                                      SizedBox(height: padding),
                                      if (_stats != null) ...[
                                        _buildFiltersSection(),
                                        SizedBox(height: padding),
                                        Text(
                                          AppStrings.t('totals_with_filters', locale),
                                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        _buildStatsGrid(_stats!, constraints.maxWidth),
                                        SizedBox(height: padding * 1.2),
                                        _buildCountriesSection(),
                                        SizedBox(height: padding),
                                        _buildDataTable(constraints.maxWidth),
                                      ],
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                      if (_loading && _stats != null)
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
                                    AppStrings.t('loading_data', locale),
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
    final compact = MediaQuery.of(context).size.width < 500;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _presetChip('Hoy', DateRangePreset.today, compact),
          SizedBox(width: compact ? 4 : 8),
          _presetChip('Ayer', DateRangePreset.yesterday, compact),
          SizedBox(width: compact ? 4 : 8),
          _presetChip('7d', DateRangePreset.last7, compact),
          SizedBox(width: compact ? 4 : 8),
          _presetChip('30d', DateRangePreset.last30, compact),
          SizedBox(width: compact ? 4 : 8),
          _presetChip('90d', DateRangePreset.last90, compact),
          SizedBox(width: compact ? 4 : 8),
          FilterChip(
            label: Text(compact ? AppStrings.t('filter_date', LocaleNotifier.current) : AppStrings.t('filter_custom', LocaleNotifier.current)),
            selected: _filters.datePreset == DateRangePreset.custom,
            onSelected: (_) => _pickDateRange(),
            avatar: Icon(Icons.calendar_today, size: compact ? 14 : 18),
            selectedColor: Theme.of(context).colorScheme.primaryContainer,
            checkmarkColor: Theme.of(context).colorScheme.primary,
            showCheckmark: true,
            padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 12, vertical: compact ? 4 : 8),
            visualDensity: compact ? VisualDensity.compact : VisualDensity.standard,
          ),
        ],
      ),
    );
  }

  Widget _presetChip(String label, DateRangePreset preset, bool compact) {
    final selected = _filters.datePreset == preset;
    return FilterChip(
      label: Text(label, style: TextStyle(fontSize: compact ? 12 : null)),
      selected: selected,
      onSelected: (_) => _applyPreset(preset),
      selectedColor: Theme.of(context).colorScheme.primaryContainer,
      checkmarkColor: Theme.of(context).colorScheme.primary,
      showCheckmark: true,
      padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 12, vertical: compact ? 4 : 8),
      visualDensity: compact ? VisualDensity.compact : VisualDensity.standard,
    );
  }

  Widget _wrapMetricCard(String title, String value, IconData icon, [String? metricId]) {
    final id = metricId ?? _statCardMetricIds[title] ?? 'revenue';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          await _saveFilters();
          if (!context.mounted) return;
          context.push('/dashboard/metric/$id');
        },
        borderRadius: BorderRadius.circular(16),
        child: StatCard(
          title: title,
          value: value,
          icon: icon,
        ),
      ),
    );
  }

  Widget _buildStatsGrid(DashboardStats s, double width) {
    final l = LocaleNotifier.current;
    final crossCount = width > 900 ? 4 : (width > 600 ? 3 : 2);
    final cards = <Widget>[
      _wrapMetricCard(AppStrings.t('ingresos', l), formatMoney(s.revenue), Icons.attach_money, 'revenue'),
      _wrapMetricCard(AppStrings.t('impressions', l), formatNumber(s.impressions), Icons.visibility, 'impressions'),
      _wrapMetricCard(AppStrings.t('ecpm', l), formatMoney(s.ecpm), Icons.trending_up, 'ecpm'),
      if (s.clicks != null)
        _wrapMetricCard(AppStrings.t('clicks', l), formatNumber(s.clicks!), Icons.touch_app, 'clicks'),
      if (s.completions != null)
        _wrapMetricCard(AppStrings.t('completions', l), formatNumber(s.completions!), Icons.check_circle, 'completions'),
      if (s.fillRate != null && s.fillRate! > 0)
        _wrapMetricCard(AppStrings.t('fill_rate', l), '${formatDecimal(s.fillRate!)}%', Icons.pie_chart_outline, 'fill_rate'),
      if (s.completionRate != null && s.completionRate! > 0)
        _wrapMetricCard(AppStrings.t('completion_rate', l), '${formatDecimal(s.completionRate!)}%', Icons.done_all, 'completion_rate'),
      if (s.revenuePerCompletion != null && s.revenuePerCompletion! > 0)
        _wrapMetricCard(AppStrings.t('revenue_per_completion', l), formatMoney(s.revenuePerCompletion!), Icons.monetization_on_outlined, 'revenue_per_completion'),
      if (s.ctr != null && s.ctr! > 0)
        _wrapMetricCard(AppStrings.t('ctr', l), '${formatDecimal(s.ctr!)}%', Icons.ads_click, 'ctr'),
      if (s.appRequests != null && s.appRequests! > 0)
        _wrapMetricCard(AppStrings.t('app_requests', l), formatNumber(s.appRequests!), Icons.sync, 'app_requests'),
      if (s.dau != null && s.dau! > 0)
        _wrapMetricCard(AppStrings.t('dau', l), formatNumber(s.dau!), Icons.people, 'dau'),
      if (s.sessions != null && s.sessions! > 0)
        _wrapMetricCard(AppStrings.t('sessions', l), formatNumber(s.sessions!), Icons.event_note, 'sessions'),
    ];
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: crossCount,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: width > 600 ? 1.5 : 1.25,
      children: cards,
    );
  }

  /// Filas de metadata filtradas por los filtros actuales (para tabla por país).
  List<IronSourceStatsRow> get _filteredMetadataRows {
    if (_filterMetadataRows.isEmpty) return [];
    final appKeys = _filters.appKeys;
    final countries = _filters.countries;
    final adUnits = _filters.adUnits;
    final platforms = _filters.platforms;
    final hasApp = appKeys != null && appKeys.isNotEmpty;
    final hasCountry = countries != null && countries.isNotEmpty;
    final hasAdUnit = adUnits != null && adUnits.isNotEmpty;
    final hasPlatform = platforms != null && platforms.isNotEmpty;
    if (!hasApp && !hasCountry && !hasAdUnit && !hasPlatform) return _filterMetadataRows;
    return _filterMetadataRows.where((row) {
      if (hasApp && !appKeys.contains((row.appKey ?? '').trim())) return false;
      if (hasCountry && !countries.contains((row.country ?? '').trim().toUpperCase())) return false;
      if (hasPlatform && !platforms.contains((row.platform ?? '').trim().toLowerCase())) return false;
      if (hasAdUnit) {
        final rowAd = (row.adUnits ?? '').toLowerCase();
        final matches = adUnits.any((f) => rowAd.contains(f.toLowerCase()) || f.toLowerCase().contains(rowAd) || (f == 'rewardedVideo' && rowAd.contains('rewarded')) || (f == 'offerWall' && rowAd.contains('offer')));
        if (!matches) return false;
      }
      return true;
    }).toList();
  }

  List<Map<String, dynamic>> _aggregateByCountry() {
    final byCountry = <String, Map<String, dynamic>>{};
    for (final row in _filteredMetadataRows) {
      final countryKey = (row.country ?? '').trim().isEmpty ? '__all__' : (row.country!.trim().toUpperCase());
      for (final d in row.data ?? []) {
        final rev = _rev(d);
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
              'revenue': e.value['revenue'] as num,
              'impressions': e.value['impressions'] as int,
            })
        .toList()
      ..sort((a, b) => (b['revenue'] as num).compareTo(a['revenue'] as num));
  }

  Widget _buildCountriesSection() {
    final byCountry = _aggregateByCountry();
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
              cs.primary.withValues(alpha: 0.1),
              cs.tertiary.withValues(alpha: 0.06),
            ],
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.public, color: Theme.of(context).colorScheme.tertiary, size: 20),
                ),
                const SizedBox(width: 10),
                Text(
                  AppStrings.t('by_country', LocaleNotifier.current),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (byCountry.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'Puede haber discrepancias de centésimas en esta tabla.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 10,
                    color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                ),
              ),
            if (byCountry.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  AppStrings.t('no_country_data', LocaleNotifier.current),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LayoutBuilder(
                    builder: (context, c) {
                      final w = c.maxWidth;
                      final colRev = w > 400 ? 90.0 : 70.0;
                      final colImp = w > 400 ? 95.0 : 82.0;
                      final colCountry = w - colRev - colImp - 16;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              SizedBox(
                                width: colCountry,
                                child: Text(
                                  AppStrings.t('filter_country', LocaleNotifier.current),
                                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                                      ),
                                  overflow: TextOverflow.visible,
                                ),
                              ),
                              SizedBox(
                                width: colRev,
                                child: Text(
                                  AppStrings.t('revenue', LocaleNotifier.current),
                                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                                      ),
                                  textAlign: TextAlign.end,
                                  overflow: TextOverflow.visible,
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: colImp,
                                child: Text(
                                  AppStrings.t('impressions', LocaleNotifier.current),
                                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                                      ),
                                  textAlign: TextAlign.end,
                                  overflow: TextOverflow.visible,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ...byCountry.take(12).map((r) {
                            final code = r['countryCode'] as String?;
                            final name = formatCountry(code);
                            final rev = (r['revenue'] as num).toDouble();
                            final imp = r['impressions'] as int;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: colCountry,
                                    child: Text(
                                      name,
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w500,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  SizedBox(
                                    width: colRev,
                                    child: Text(
                                      formatMoney(rev),
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: Theme.of(context).colorScheme.primary,
                                      ),
                                      textAlign: TextAlign.end,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  SizedBox(
                                    width: colImp,
                                    child: Text(
                                      formatNumber(imp),
                                      style: Theme.of(context).textTheme.bodySmall,
                                      textAlign: TextAlign.end,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      );
                    },
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  /// Lista unificada: countryCodesForFilter + países que aparecen en los datos.
  /// Con breakdowns: 'date' las filas no tienen country; usamos _filterMetadataRows.
  List<String> get _countryFilterOptions {
    final base = countryCodesForFilter.toSet();
    for (final row in _filterMetadataRows) {
      final c = (row.country ?? '').trim().toUpperCase();
      if (c.isNotEmpty) base.add(c);
    }
    return base.toList()..sort();
  }

  Widget _buildFiltersSection() {
    final isWide = MediaQuery.of(context).size.width > 700;
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
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.filter_list, color: Theme.of(context).colorScheme.primary, size: 20),
                ),
                const SizedBox(width: 10),
                Text(
                  AppStrings.t('filters', LocaleNotifier.current),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 400;
                final dropWidth = compact ? 110.0 : (constraints.maxWidth > 700 ? 180.0 : 140.0);
                final maxW = constraints.maxWidth;
                if (isWide) {
                  return ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxW),
                    child: ClipRect(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        clipBehavior: Clip.hardEdge,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(width: dropWidth, child: _buildAppDropdown(compact)),
                            SizedBox(width: compact ? 6.0 : 12.0),
                            SizedBox(width: dropWidth, child: _buildAdUnitDropdown(compact)),
                            SizedBox(width: compact ? 6.0 : 12.0),
                            SizedBox(width: compact ? 100.0 : 140.0, child: _buildPlatformDropdown(compact)),
                            SizedBox(width: compact ? 6.0 : 12.0),
                            SizedBox(width: dropWidth, child: _buildCountryDropdown(compact)),
                          ],
                        ),
                      ),
                    ),
                  );
                }
                return ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxW),
                  child: Wrap(
                    spacing: compact ? 8.0 : 12.0,
                    runSpacing: compact ? 8.0 : 12.0,
                    children: [
                      SizedBox(width: (maxW - (compact ? 8.0 : 12.0)) / 2, child: _buildAppDropdown(compact)),
                      SizedBox(width: (maxW - (compact ? 8.0 : 12.0)) / 2, child: _buildAdUnitDropdown(compact)),
                      SizedBox(width: (maxW - (compact ? 8.0 : 12.0)) / 2, child: _buildPlatformDropdown(compact)),
                      SizedBox(width: (maxW - (compact ? 8.0 : 12.0)) / 2, child: _buildCountryDropdown(compact)),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppDropdown([bool compact = false]) {
    final apps = _apps.where((a) => (a.appKey ?? '').isNotEmpty).toList();
    final selected = _filters.appKeys ?? [];
    final selectedSet = selected.toSet();
    final optsCount = apps.length;
    final allSelected = selected.isNotEmpty && optsCount > 0 &&
        apps.every((a) => selectedSet.contains(a.appKey));
    final l = LocaleNotifier.current;
    String valueLabel;
    if (selected.isEmpty || allSelected) {
      valueLabel = AppStrings.t('all_apps', l);
    } else if (selected.length == 1) {
      final a = apps.cast<IronSourceApp?>().firstWhere((x) => x?.appKey == selected.single, orElse: () => null);
      valueLabel = a != null ? '${a.appName ?? a.appKey} (${a.platform ?? ''})' : selected.single;
    } else {
      valueLabel = '${selected.length} ${AppStrings.t('apps_count', l)}';
    }
    return _buildFilterChip(
      label: AppStrings.t('app_filter', l),
      valueLabel: valueLabel,
      compact: compact,
      onTap: () async {
        final options = apps.map((a) => '${a.appKey}|${a.platform ?? ''}').toList();
        final labels = apps.map((a) => '${a.appName ?? a.appKey} (${a.platform ?? ''})').toList();
        final allSelectedForDialog = selected.isEmpty || (optsCount > 0 && apps.every((a) => selectedSet.contains(a.appKey)));
        final initialSelected = allSelectedForDialog
            ? options.toSet()
            : apps.where((a) => selectedSet.contains(a.appKey)).map((a) => '${a.appKey}|${a.platform ?? ''}').toSet();
        final chosen = await _showMultiSelect(
          title: AppStrings.t('app_filter', l),
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
      },
    );
  }

  Widget _buildAdUnitDropdown([bool compact = false]) {
    const options = ['rewardedVideo', 'interstitial', 'banner', 'offerWall'];
    final l = LocaleNotifier.current;
    final labels = [AppStrings.t('rewarded_video', l), AppStrings.t('interstitial', l), AppStrings.t('banner', l), AppStrings.t('offerwall', l)];
    final selected = _filters.adUnits ?? [];
    final label = selected.isEmpty || selected.length >= options.length ? AppStrings.t('all', l) : (selected.length == 1 ? labels[options.indexOf(selected.single)] : '${selected.length} ${AppStrings.t('ad_types_count', l)}');
    return _buildFilterChip(
      label: compact ? AppStrings.t('filter_ad_compact', l) : AppStrings.t('filter_ad_type', l),
      valueLabel: label,
      compact: compact,
      onTap: () async {
        final allSelected = selected.isEmpty || selected.length >= options.length;
        final chosen = await _showMultiSelect(title: AppStrings.t('filter_ad_type', l), options: options, labels: labels, selected: allSelected ? options.toSet() : selected.toSet());
        if (chosen != null && mounted) {
          final all = chosen.isEmpty || chosen.length >= options.length;
          setState(() => _filters = _filters.copyWith(adUnits: all ? null : chosen, clearAdUnits: all));
          _onFiltersChanged();
        }
      },
    );
  }

  Widget _buildPlatformDropdown([bool compact = false]) {
    const options = ['android', 'ios'];
    final l = LocaleNotifier.current;
    final labels = [AppStrings.t('android', l), AppStrings.t('ios', l)];
    final selected = _filters.platforms ?? [];
    final label = selected.isEmpty || selected.length >= options.length ? AppStrings.t('all_platforms', l) : (selected.length == 1 ? labels[options.indexOf(selected.single)] : '${selected.length} ${AppStrings.t('platforms_count', l)}');
    return _buildFilterChip(
      label: compact ? AppStrings.t('filter_os_compact', l) : AppStrings.t('filter_platform', l),
      valueLabel: label,
      compact: compact,
      onTap: () async {
        final allSelected = selected.isEmpty || selected.length >= 2;
        final chosen = await _showMultiSelect(title: AppStrings.t('filter_platform', l), options: options, labels: labels, selected: allSelected ? options.toSet() : selected.toSet());
        if (chosen != null && mounted) {
          final all = chosen.isEmpty || chosen.length >= 2;
          setState(() => _filters = _filters.copyWith(platforms: all ? null : chosen, clearPlatforms: all));
          _onFiltersChanged();
        }
      },
    );
  }

  Widget _buildCountryDropdown([bool compact = false]) {
    final l = LocaleNotifier.current;
    final options = _countryFilterOptions;
    final selected = _filters.countries ?? [];
    final allSelected = selected.isNotEmpty && options.isNotEmpty &&
        selected.toSet().containsAll(options) && options.toSet().containsAll(selected);
    final label = selected.isEmpty || allSelected ? AppStrings.t('all', l) : (selected.length == 1 ? formatCountry(selected.single) : '${selected.length} ${AppStrings.t('countries_count', l)}');
    return _buildFilterChip(
      label: AppStrings.t('filter_country', l),
      valueLabel: label,
      compact: compact,
      onTap: () async {
        final allSelectedForDialog = selected.isEmpty || allSelected;
        final chosen = await _showMultiSelect(
          title: AppStrings.t('filter_country', l),
          options: options,
          labels: options.map(formatCountry).toList(),
          selected: allSelectedForDialog ? options.toSet() : selected.toSet(),
        );
        if (chosen != null && mounted) {
          final all = chosen.isEmpty || chosen.length >= options.length;
          setState(() => _filters = _filters.copyWith(countries: all ? null : chosen, clearCountries: all));
          _onFiltersChanged();
        }
      },
    );
  }

  Widget _buildFilterChip({
    required String label,
    required String valueLabel,
    required bool compact,
    required VoidCallback onTap,
  }) {
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

  List<Map<String, dynamic>> _aggregateRowsByDate() {
    final byDate = <String, Map<String, dynamic>>{};
    for (final row in _rawRows) {
      final date = row.date ?? '';
      if (date.isEmpty) continue;
      for (final d in row.data ?? []) {
        final rev = _rev(d);
        final imp = (d['impressions'] is num) ? (d['impressions'] as num).toInt() : 0;
        final clk = (d['clicks'] is num) ? (d['clicks'] as num).toInt() : 0;
        final comp = (d['completions'] is num) ? (d['completions'] as num).toInt() : 0;
        final appReq = (d['appRequests'] is num) ? (d['appRequests'] as num).toInt() : 0;
        final dauVal = (d['dau'] is num) ? (d['dau'] as num).toInt() : 0;
        final sess = (d['sessions'] is num) ? (d['sessions'] as num).toInt() : 0;
        final fr = (d['appFillRate'] is num) ? (d['appFillRate'] as num).toDouble() : 0.0;
        final cr = (d['completionRate'] is num) ? (d['completionRate'] as num).toDouble() : 0.0;
        final rpc = (d['revenuePerCompletion'] is num) ? (d['revenuePerCompletion'] as num).toDouble() : 0.0;
        final ctr = (d['clickThroughRate'] is num) ? (d['clickThroughRate'] as num).toDouble() : 0.0;
        if (!byDate.containsKey(date)) {
          byDate[date] = {
            'revenue': 0.0, 'impressions': 0, 'clicks': 0, 'completions': 0,
            'appRequests': 0, 'dau': 0, 'sessions': 0,
            'fillRateSum': 0.0, 'fillRateCount': 0,
            'completionRateSum': 0.0, 'completionRateCount': 0,
            'revPerCompSum': 0.0, 'revPerCompCount': 0,
            'ctrSum': 0.0, 'ctrCount': 0,
          };
        }
        final acc = byDate[date]!;
        acc['revenue'] = (acc['revenue'] as num) + rev;
        acc['impressions'] = (acc['impressions'] as int) + imp;
        acc['clicks'] = (acc['clicks'] as int) + clk;
        acc['completions'] = (acc['completions'] as int) + comp;
        acc['appRequests'] = (acc['appRequests'] as int) + appReq;
        acc['dau'] = (acc['dau'] as int) + dauVal;
        acc['sessions'] = (acc['sessions'] as int) + sess;
        if (fr > 0) { acc['fillRateSum'] = (acc['fillRateSum'] as num) + fr; acc['fillRateCount'] = (acc['fillRateCount'] as int) + 1; }
        if (cr > 0) { acc['completionRateSum'] = (acc['completionRateSum'] as num) + cr; acc['completionRateCount'] = (acc['completionRateCount'] as int) + 1; }
        if (rpc > 0) { acc['revPerCompSum'] = (acc['revPerCompSum'] as num) + rpc; acc['revPerCompCount'] = (acc['revPerCompCount'] as int) + 1; }
        if (ctr > 0) { acc['ctrSum'] = (acc['ctrSum'] as num) + ctr; acc['ctrCount'] = (acc['ctrCount'] as int) + 1; }
      }
    }
    final list = byDate.entries.map((e) {
      final v = e.value;
      final rev = (v['revenue'] as num).toDouble();
      final imp = v['impressions'] as int;
      final comp = v['completions'] as int;
      final fillCount = v['fillRateCount'] as int;
      final crCount = v['completionRateCount'] as int;
      final rpcCount = v['revPerCompCount'] as int;
      final ctrCount = v['ctrCount'] as int;
      return <String, dynamic>{
        'date': e.key,
        'revenue': rev,
        'impressions': imp,
        'eCPM': imp > 0 ? (rev / imp) * 1000 : 0.0,
        'clicks': v['clicks'] as int,
        'completions': comp,
        'fillRate': fillCount > 0 ? (v['fillRateSum'] as num) / fillCount : null,
        'completionRate': crCount > 0 ? (v['completionRateSum'] as num) / crCount : (imp > 0 && comp > 0 ? (comp / imp) * 100 : null),
        'revenuePerCompletion': rpcCount > 0 ? (v['revPerCompSum'] as num) / rpcCount : (comp > 0 ? rev / comp : null),
        'ctr': ctrCount > 0 ? (v['ctrSum'] as num) / ctrCount : null,
        'appRequests': (v['appRequests'] as int) > 0 ? v['appRequests'] : null,
        'dau': (v['dau'] as int) > 0 ? v['dau'] : null,
        'sessions': (v['sessions'] as int) > 0 ? v['sessions'] : null,
      };
    }).toList();
    list.sort((a, b) => (b['date'] as String).compareTo(a['date'] as String));
    return list;
  }

  List<DataRow> _dataTableRows(List<Map<String, dynamic>> aggregated) {
    return aggregated.map((r) {
      final dateStr = r['date'] as String;
      final impressions = r['impressions'] as int;
      final ecpm = (r['eCPM'] as num).toDouble();
      final clicks = r['clicks'] as int;
      final completions = r['completions'] as int;
      final fillRate = r['fillRate'] as double?;
      final completionRate = r['completionRate'] as double?;
      final revPerComp = r['revenuePerCompletion'] as double?;
      final ctr = r['ctr'] as double?;
      final appRequests = r['appRequests'] as int?;
      final dau = r['dau'] as int?;
      final sessions = r['sessions'] as int?;
      return DataRow(
        cells: [
          DataCell(Tooltip(message: dateStr, child: Text(dateStr))),
          DataCell(_cell(formatMoney((r['revenue'] as num).toDouble()))),
          DataCell(_cell(formatNumber(impressions))),
          DataCell(_cell(formatMoney(ecpm))),
          DataCell(_cell(formatNumber(clicks))),
          DataCell(_cell(formatNumber(completions))),
          DataCell(_cell(fillRate != null ? '${formatDecimal(fillRate)}%' : '—')),
          DataCell(_cell(completionRate != null ? '${formatDecimal(completionRate)}%' : '—')),
          DataCell(_cell(revPerComp != null ? formatMoney(revPerComp) : '—')),
          DataCell(_cell(ctr != null ? '${formatDecimal(ctr)}%' : '—')),
          DataCell(_cell(appRequests != null ? formatNumber(appRequests) : '—')),
          DataCell(_cell(dau != null ? formatNumber(dau) : '—')),
          DataCell(_cell(sessions != null ? formatNumber(sessions) : '—')),
        ],
      );
    }).toList();
  }

  Widget _cell(String text) => Tooltip(message: text, child: SelectableText(text));

  Widget _buildDataTable(double width) {
    if (_rawRows.isEmpty) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(child: Text(AppStrings.t('no_data_table', LocaleNotifier.current))),
        ),
      );
    }
    final aggregated = _aggregateRowsByDate();
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
              cs.primary.withValues(alpha: 0.1),
              cs.tertiary.withValues(alpha: 0.05),
            ],
          ),
        ),
        padding: const EdgeInsets.all(20),
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
                  child: Icon(Icons.table_chart, color: cs.primary, size: 20),
                ),
                const SizedBox(width: 10),
                Text(
                  AppStrings.t('totals_by_day', LocaleNotifier.current),
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
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                ),
                dataRowColor: WidgetStateProperty.resolveWith((states) => null),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                ),
                columns: [
                  DataColumn(label: Text(AppStrings.t('date', LocaleNotifier.current))),
                  DataColumn(label: Text(AppStrings.t('income', LocaleNotifier.current)), numeric: true),
                  DataColumn(label: Text(AppStrings.t('impressions', LocaleNotifier.current)), numeric: true),
                  DataColumn(label: Text(AppStrings.t('ecpm', LocaleNotifier.current)), numeric: true),
                  DataColumn(label: Text(AppStrings.t('clicks', LocaleNotifier.current)), numeric: true),
                  DataColumn(label: Text(AppStrings.t('completions', LocaleNotifier.current)), numeric: true),
                  DataColumn(label: Text(AppStrings.t('fill_rate', LocaleNotifier.current)), numeric: true),
                  DataColumn(label: Text(AppStrings.t('completion_rate', LocaleNotifier.current)), numeric: true),
                  DataColumn(label: Text(AppStrings.t('rev_comp', LocaleNotifier.current)), numeric: true),
                  DataColumn(label: Text(AppStrings.t('ctr', LocaleNotifier.current)), numeric: true),
                  DataColumn(label: Text(AppStrings.t('app_requests', LocaleNotifier.current)), numeric: true),
                  DataColumn(label: Text(AppStrings.t('dau', LocaleNotifier.current)), numeric: true),
                  DataColumn(label: Text(AppStrings.t('sessions', LocaleNotifier.current)), numeric: true),
                ],
                rows: _dataTableRows(aggregated),
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
            Icon(
              Icons.error_outline_rounded,
              size: 56,
              color: Theme.of(context).colorScheme.error.withValues(alpha: 0.9),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(AppStrings.t('retry', LocaleNotifier.current)),
            ),
          ],
        ),
      ),
    );
  }
}
