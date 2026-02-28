import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../features/ask_ai/ask_ai_chat_bubble.dart';
import '../widgets/metric_detail_content.dart';
import '../../../../core/credentials_updated_notifier.dart';
import '../../../../core/l10n/app_strings.dart';
import '../../../../core/locale_notifier.dart';
import '../../../../core/theme/theme_mode_notifier.dart';
import '../../../../data/credentials/credentials_repository.dart';
import '../../../../data/ironsource/ironsource_api_client.dart';
import '../../../../shared/utils/formatters.dart';
import '../../../../shared/widgets/multi_select_dialog.dart';
import '../../../../shared/widgets/error_retry_body.dart';
import '../../../../shared/widgets/wave_loading_indicator.dart';
import '../../data/dashboard_repository.dart';
import '../../domain/dashboard_filters.dart';
import '../../domain/dashboard_stats.dart';

double _rev(Map<String, dynamic> d) => (d['revenue'] is num) ? (d['revenue'] as num).toDouble() : 0;

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final DashboardRepository _repo = DashboardRepository();
  final CredentialsRepository _credentials = CredentialsRepository();

  DashboardFilters _filters = DashboardFilters.last7Days();
  DateRangePreset _displayDatePreset = DateRangePreset.last7;
  DashboardStats? _stats;
  DashboardStats? _prevStats;
  DashboardStats? _displayStats;
  DashboardStats? _displayPrevStats;
  List<IronSourceStatsRow> _rawRows = [];
  List<IronSourceStatsRow> _tableRawRows = []; // Solo filtro fecha, para tablas
  List<IronSourceApp> _apps = [];
  List<IronSourceStatsRow> _filterMetadataRows = [];
  bool _loading = true;
  String? _error;
  bool _filtersExpanded = false;
  int _currentTabIndex = 0;
  int _detailsMetricIndex = 0;
  late final PageController _mainPageController = PageController();

  // Cache: por fechas + filtros (se envían a la API)
  List<IronSourceStatsRow> _cachedRawRows = [];
  List<IronSourceStatsRow> _cachedTableRawRows = [];
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
    final saved = await DashboardFilters.loadDashboard();
    if (mounted) {
      setState(() => _filters = saved);
      await _checkCredentials();
    }
  }

  @override
  void dispose() {
    _mainPageController.dispose();
    ThemeModeNotifier.valueNotifier.removeListener(_onThemeChanged);
    CredentialsUpdatedNotifier.instance.removeListener(_onCredentialsUpdated);
    super.dispose();
  }

  static const List<String> _metricIds = [
    'revenue', 'impressions', 'ecpm', 'clicks', 'completions',
    'fill_rate', 'completion_rate', 'revenue_per_completion',
    'ctr', 'app_requests', 'dau', 'sessions',
  ];

  void _onCredentialsUpdated() {
    if (!mounted) return;
    _cachedRawRows = [];
    _cachedTableRawRows = [];
    _tableRawRows = [];
    _cachedStartDate = null;
    _cachedEndDate = null;
    _load();
  }

  void _onFiltersChanged() {
    _saveFilters(); // Persistir filtros
    _load(); // Refetch: filtros se envían a la API
  }

  Future<void> _checkCredentials() async {
    final hasCredentials = await _credentials.hasCredentials();
    if (!mounted) return;
    if (!hasCredentials) {
      context.go('/credentials');
      return;
    }
    final valid = await DashboardRepository().validateCredentials();
    if (!mounted) return;
    if (!valid) {
      context.go('/credentials');
      return;
    }
    _load();
  }

  /// Cache válido si fechas y filtros coinciden (los filtros se envían a la API).
  bool get _isCacheValid =>
      _cachedStartDate == _filters.startDateStr &&
      _cachedEndDate == _filters.endDateStr &&
      _cachedFilterKey == _filterKey;

  String get _filterKey =>
      '${_filters.appKeys?.join(',') ?? ''}|${_filters.countries?.join(',') ?? ''}|${_filters.adUnits?.join(',') ?? ''}|${_filters.platforms?.join(',') ?? ''}';

  /// Con breakdowns: 'date' los filtros se envían a la API. Si no hay datos, todo en 0.
  void _applyFiltersFromCache() {
    _rawRows = _cachedRawRows;
    _tableRawRows = _cachedTableRawRows;
    _stats = DashboardRepository.statsFromRows(_cachedRawRows);
    _displayStats = _stats;
    _displayDatePreset = _filters.datePreset;
    setState(() {});
    _loadPrevStats();
  }

  Future<void> _loadPrevStats() async {
    try {
      final prev = await _repo.getPreviousPeriodStats(_filters);
      if (mounted) {
        setState(() {
          _prevStats = prev;
          _displayStats = _stats;
          _displayPrevStats = prev;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _displayStats = _stats;
          _displayPrevStats = null;
        });
      }
    }
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
      final tableFuture = _repo.getStatsRaw(dateFilters); // Solo fecha para tablas
      final metadataFuture = _repo.getFilterMetadata(dateFilters);
      if (_apps.isEmpty) {
        try {
          _apps = await _repo.getApplications();
        } catch (_) {}
      }
      if (!mounted) return;
      _cachedRawRows = full;
      _cachedTableRawRows = await tableFuture;
      _tableRawRows = _cachedTableRawRows;
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
        if (_isKeysError(e.toString())) {
          context.go('/credentials');
          return;
        }
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
    return ValueListenableBuilder<String>(
      valueListenable: LocaleNotifier.valueNotifier,
      builder: (context, locale, _) => Scaffold(
      appBar: AppBar(
        toolbarHeight: 44,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_heroBlueStart, _heroBlueEnd],
            ),
          ),
        ),
        leading: IconButton(
          icon: Icon(
            ThemeModeNotifier.current == ThemeMode.light ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
            color: _heroTextPrimary,
          ),
          onPressed: () {
            ThemeModeNotifier.set(
              ThemeModeNotifier.current == ThemeMode.light ? ThemeMode.dark : ThemeMode.light,
            );
          },
          tooltip: ThemeModeNotifier.current == ThemeMode.light ? AppStrings.t('dark_mode', locale) : AppStrings.t('light_mode', locale),
        ),
        title: Text(
          _currentTabIndex == 0 ? AppStrings.t('tab_home', locale)
              : _currentTabIndex == 1 ? AppStrings.t('tab_table', locale)
              : AppStrings.t('tab_details', locale),
          style: const TextStyle(color: _heroTextPrimary, fontSize: 17),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: _heroTextPrimary),
            onPressed: () => context.push('/credentials'),
            tooltip: AppStrings.t('settings_tooltip', locale),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentTabIndex,
        onDestinationSelected: (i) {
          setState(() => _currentTabIndex = i);
          final page = i == 0 ? 0 : i == 1 ? 1 : 2 + _detailsMetricIndex;
          _mainPageController.animateToPage(page, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
        },
        destinations: [
          NavigationDestination(icon: const Icon(Icons.home_outlined), selectedIcon: const Icon(Icons.home), label: AppStrings.t('tab_home', locale)),
          NavigationDestination(icon: const Icon(Icons.table_chart_outlined), selectedIcon: const Icon(Icons.table_chart), label: AppStrings.t('tab_table', locale)),
          NavigationDestination(icon: const Icon(Icons.bar_chart_outlined), selectedIcon: const Icon(Icons.bar_chart), label: AppStrings.t('tab_details', locale)),
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
                ? ErrorRetryBody(
                    message: _DashboardScreenState._isKeysError(_error)
                        ? AppStrings.t('invalid_keys', locale)
                        : _error!,
                    isNetworkError: _DashboardScreenState._isNetworkError(_error ?? ''),
                    onRetry: _load,
                  )
                : Stack(
                    children: [
                      PageView(
                        controller: _mainPageController,
                        physics: const BouncingScrollPhysics(),
                        onPageChanged: (i) {
                          setState(() {
                            if (i == 0) {
                              _currentTabIndex = 0;
                            } else if (i == 1) {
                              _currentTabIndex = 1;
                            } else {
                              _currentTabIndex = 2;
                              _detailsMetricIndex = i - 2;
                            }
                          });
                        },
                        children: [
                          _buildHomeTab(locale),
                          _buildTableTab(locale),
                          ...List.generate(_metricIds.length, (j) => _buildDetailPageWithFilters(_metricIds[j], locale)),
                        ],
                      ),
                      if (_loading && _stats != null)
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: Material(
                            elevation: 0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              color: Theme.of(context).colorScheme.primaryContainer,
                              child: Center(
                                child: WaveLoadingIndicator(
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      AskAiChatBubble(dataSummary: _buildDataSummaryForAi()),
                    ],
                  ),
      ),
    ));
  }

  Widget _buildHomeTab(String locale) {
    final width = MediaQuery.of(context).size.width;
    final padding = width > 900 ? 24.0 : (width > 600 ? 20.0 : 12.0);
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(padding, 8, padding, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildDateFilters(),
          SizedBox(height: padding),
          if (_stats != null) ...[
            _buildFiltersSection(),
            SizedBox(height: padding),
            _buildMainHeroCard(locale),
            SizedBox(height: padding),
            ..._buildSecondaryCardsList(locale),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildSecondaryCardsList(String locale) {
    final s = _stats!;
    final l = LocaleNotifier.current;
    final items = <Widget>[
      _buildSecondaryCardRow(AppStrings.t('revenue', l), formatMoney(s.revenue), Icons.monetization_on_outlined, 'revenue', 0),
      _buildSecondaryCardRow(AppStrings.t('impressions', l), formatNumber(s.impressions), Icons.visibility, 'impressions', 0),
      _buildSecondaryCardRow(AppStrings.t('ecpm', l), formatMoney(s.ecpm), Icons.trending_up, 'ecpm', 0),
    ];
    if (s.clicks != null) items.add(_buildSecondaryCardRow(AppStrings.t('clicks', l), formatNumber(s.clicks!), Icons.touch_app, 'clicks', 0));
    if (s.completions != null) items.add(_buildSecondaryCardRow(AppStrings.t('completions', l), formatNumber(s.completions!), Icons.check_circle, 'completions', 0));
    if (s.fillRate != null && s.fillRate! > 0) items.add(_buildSecondaryCardRow(AppStrings.t('fill_rate', l), '${formatDecimal(s.fillRate!)}%', Icons.pie_chart_outline, 'fill_rate', 0));
    if (s.completionRate != null && s.completionRate! > 0) items.add(_buildSecondaryCardRow(AppStrings.t('completion_rate', l), '${formatDecimal(s.completionRate!)}%', Icons.done_all, 'completion_rate', 0));
    if (s.revenuePerCompletion != null && s.revenuePerCompletion! > 0) items.add(_buildSecondaryCardRow(AppStrings.t('revenue_per_completion', l), formatMoney(s.revenuePerCompletion!), Icons.monetization_on_outlined, 'revenue_per_completion', 0));
    if (s.ctr != null && s.ctr! > 0) items.add(_buildSecondaryCardRow(AppStrings.t('ctr', l), '${formatDecimal(s.ctr!)}%', Icons.ads_click, 'ctr', 0));
    if (s.appRequests != null && s.appRequests! > 0) items.add(_buildSecondaryCardRow(AppStrings.t('app_requests', l), formatNumber(s.appRequests!), Icons.sync, 'app_requests', 0));
    if (s.dau != null && s.dau! > 0) items.add(_buildSecondaryCardRow(AppStrings.t('dau', l), formatNumber(s.dau!), Icons.people, 'dau', 0));
    if (s.sessions != null && s.sessions! > 0) items.add(_buildSecondaryCardRow(AppStrings.t('sessions', l), formatNumber(s.sessions!), Icons.event_note, 'sessions', 0));
    return items;
  }

  Widget _buildSecondaryCardRow(String title, String value, IconData icon, String metricId, int _) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _goToDetailTab(metricId),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(title, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTableTab(String locale) {
    final width = MediaQuery.of(context).size.width;
    final padding = width > 900 ? 24.0 : (width > 600 ? 20.0 : 12.0);
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(padding, 8, padding, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildDateFilters(),
          SizedBox(height: padding),
          if (_stats != null) ...[
            _buildCollapsibleTableSections(padding),
          ],
        ],
      ),
    );
  }

  bool _totalsByDayExpanded = true;
  bool _byCountryExpanded = false;
  bool _byAppExpanded = false;
  bool _byAdExpanded = false;
  bool _byPlatformExpanded = false;

  Widget _buildCollapsibleTableSections(double padding) {
    final width = MediaQuery.of(context).size.width;
    final l = LocaleNotifier.current;
    return Column(
      children: [
        _buildCollapsibleSection(
          title: AppStrings.t('totals_by_day', l),
          expanded: _totalsByDayExpanded,
          onToggle: () => setState(() => _totalsByDayExpanded = !_totalsByDayExpanded),
          child: _buildDataTable(width, showHeader: false),
        ),
        SizedBox(height: padding),
        _buildCollapsibleSection(
          title: AppStrings.t('by_country', l),
          expanded: _byCountryExpanded,
          onToggle: () => setState(() => _byCountryExpanded = !_byCountryExpanded),
          child: _buildCountriesSection(),
        ),
        SizedBox(height: padding),
        _buildCollapsibleSection(
          title: AppStrings.t('by_app', l),
          expanded: _byAppExpanded,
          onToggle: () => setState(() => _byAppExpanded = !_byAppExpanded),
          child: _buildByAppSection(width),
        ),
        SizedBox(height: padding),
        _buildCollapsibleSection(
          title: AppStrings.t('by_ad', l),
          expanded: _byAdExpanded,
          onToggle: () => setState(() => _byAdExpanded = !_byAdExpanded),
          child: _buildByAdSection(width),
        ),
        SizedBox(height: padding),
        _buildCollapsibleSection(
          title: AppStrings.t('by_platform', l),
          expanded: _byPlatformExpanded,
          onToggle: () => setState(() => _byPlatformExpanded = !_byPlatformExpanded),
          child: _buildByPlatformSection(width),
        ),
      ],
    );
  }

  Widget _buildCollapsibleSection({
    required String title,
    required bool expanded,
    required VoidCallback onToggle,
    required Widget child,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onToggle,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                    const Spacer(),
                    AnimatedRotation(
                      turns: expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(Icons.expand_more, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: child,
            ),
            crossFadeState: expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 220),
            sizeCurve: Curves.easeOut,
          ),
        ],
      ),
    );
  }

  String _appKeyToName(String? appKey) {
    if (appKey == null || appKey.isEmpty) return '-';
    final matching = _apps.where((a) => a.appKey == appKey).toList();
    if (matching.isEmpty) return appKey;
    final name = matching.first.appName ?? matching.first.appKey ?? appKey;
    final platforms = matching.map((a) => (a.platform ?? '').toLowerCase()).where((p) => p.isNotEmpty).toSet().toList()..sort();
    if (platforms.isEmpty) return name;
    final platLabel = platforms.map((p) => p == 'ios' ? AppStrings.t('ios', LocaleNotifier.current) : p == 'android' ? AppStrings.t('android', LocaleNotifier.current) : p).join(', ');
    return '$name ($platLabel)';
  }

  Widget _buildByAppSection(double width) {
    final byApp = _aggregateByApp();
    final l = LocaleNotifier.current;
    if (byApp.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(AppStrings.t('no_data_table', l), style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      );
    }
    return _buildGenericTable(
      rows: byApp.take(12).toList(),
      labelKey: 'appKey',
      labelFormatter: (v) => _appKeyToName(v),
    );
  }

  Widget _buildByAdSection(double width) {
    final byAd = _aggregateByAdUnit();
    final l = LocaleNotifier.current;
    if (byAd.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(AppStrings.t('no_data_table', l), style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      );
    }
    final adLabels = {
      'rewardedVideo': AppStrings.t('rewarded_video', l),
      'interstitial': AppStrings.t('interstitial', l),
      'banner': AppStrings.t('banner', l),
      'offerWall': AppStrings.t('offerwall', l),
    };
    return _buildGenericTable(
      rows: byAd.take(12).toList(),
      labelKey: 'adUnit',
      labelFormatter: (v) => adLabels[v ?? ''] ?? (v ?? '-'),
    );
  }

  Widget _buildByPlatformSection(double width) {
    final byPlatform = _aggregateByPlatform();
    final l = LocaleNotifier.current;
    if (byPlatform.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(AppStrings.t('no_data_table', l), style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      );
    }
    final platformLabels = {'android': AppStrings.t('android', l), 'ios': AppStrings.t('ios', l)};
    return _buildGenericTable(
      rows: byPlatform.take(12).toList(),
      labelKey: 'platform',
      labelFormatter: (v) => platformLabels[v ?? ''] ?? (v ?? '-'),
    );
  }

  Widget _buildGenericTable({
    required List<Map<String, dynamic>> rows,
    required String labelKey,
    required String Function(String?) labelFormatter,
  }) {
    final cs = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final colLabel = (w * 0.45).clamp(80.0, 220.0);
        final colRev = (w * 0.28).clamp(55.0, 100.0);
        final colImp = (w * 0.27).clamp(55.0, 100.0);
        final smallFont = w < 320;
        final labelStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w500,
          fontSize: smallFont ? 11 : null,
        );
        final numStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          fontSize: smallFont ? 10 : null,
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                SizedBox(width: colLabel, child: const SizedBox()),
                SizedBox(width: colRev, child: Text(AppStrings.t('revenue', LocaleNotifier.current), style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600, color: cs.onSurfaceVariant, fontSize: smallFont ? 10 : null), textAlign: TextAlign.end, overflow: TextOverflow.ellipsis)),
                SizedBox(width: colImp, child: Text(AppStrings.t('impressions', LocaleNotifier.current), style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600, color: cs.onSurfaceVariant, fontSize: smallFont ? 10 : null), textAlign: TextAlign.end, overflow: TextOverflow.ellipsis)),
              ],
            ),
            const SizedBox(height: 10),
            ...rows.map((r) {
              final label = labelFormatter(r[labelKey] as String?);
              final rev = (r['revenue'] as num).toDouble();
              final imp = r['impressions'] as int;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    SizedBox(width: colLabel, child: Text(label, style: labelStyle, maxLines: 1, overflow: TextOverflow.ellipsis)),
                    SizedBox(width: colRev, child: Text(formatMoney(rev), style: numStyle?.copyWith(color: cs.primary), textAlign: TextAlign.end, overflow: TextOverflow.ellipsis)),
                    SizedBox(width: colImp, child: Text(formatNumber(imp), style: numStyle, textAlign: TextAlign.end, overflow: TextOverflow.ellipsis)),
                  ],
                ),
              );
            }),
          ],
        );
      },
    );
  }

  List<Map<String, dynamic>> _aggregateByApp() {
    final byApp = <String, Map<String, dynamic>>{};
    for (final row in _filterMetadataRows) {
      final appKey = (row.appKey ?? '').trim().isEmpty ? '__all__' : row.appKey!.trim();
      for (final d in row.data ?? []) {
        final rev = _rev(d);
        final imp = (d['impressions'] is num) ? (d['impressions'] as num).toInt() : 0;
        if (!byApp.containsKey(appKey)) byApp[appKey] = {'appKey': appKey, 'revenue': 0.0, 'impressions': 0};
        byApp[appKey]!['revenue'] = (byApp[appKey]!['revenue'] as num) + rev;
        byApp[appKey]!['impressions'] = (byApp[appKey]!['impressions'] as int) + imp;
      }
    }
    return byApp.entries
        .where((e) => e.key != '__all__')
        .map((e) => {'appKey': e.key, 'revenue': e.value['revenue'], 'impressions': e.value['impressions']})
        .toList()
      ..sort((a, b) => (b['revenue'] as num).compareTo(a['revenue'] as num));
  }

  List<Map<String, dynamic>> _aggregateByAdUnit() {
    final byAd = <String, Map<String, dynamic>>{};
    for (final row in _filterMetadataRows) {
      final adStr = (row.adUnits ?? '').toLowerCase();
      String key = 'unknown';
      if (adStr.contains('rewarded')) key = 'rewardedVideo';
      else if (adStr.contains('interstitial')) key = 'interstitial';
      else if (adStr.contains('banner')) key = 'banner';
      else if (adStr.contains('offer')) key = 'offerWall';
      for (final d in row.data ?? []) {
        final rev = _rev(d);
        final imp = (d['impressions'] is num) ? (d['impressions'] as num).toInt() : 0;
        if (!byAd.containsKey(key)) byAd[key] = {'adUnit': key, 'revenue': 0.0, 'impressions': 0};
        byAd[key]!['revenue'] = (byAd[key]!['revenue'] as num) + rev;
        byAd[key]!['impressions'] = (byAd[key]!['impressions'] as int) + imp;
      }
    }
    const order = ['rewardedVideo', 'interstitial', 'banner', 'offerWall', 'unknown'];
    return byAd.entries
        .map((e) => {'adUnit': e.key, 'revenue': e.value['revenue'], 'impressions': e.value['impressions']})
        .toList()
      ..sort((a, b) {
        final ai = order.indexOf(a['adUnit'] as String);
        final bi = order.indexOf(b['adUnit'] as String);
        if (ai >= 0 && bi >= 0) return ai.compareTo(bi);
        return (b['revenue'] as num).compareTo(a['revenue'] as num);
      });
  }

  List<Map<String, dynamic>> _aggregateByPlatform() {
    final byPlatform = <String, Map<String, dynamic>>{};
    for (final row in _filterMetadataRows) {
      final platform = (row.platform ?? '').trim().toLowerCase().isEmpty ? '__all__' : (row.platform ?? '').trim().toLowerCase();
      for (final d in row.data ?? []) {
        final rev = _rev(d);
        final imp = (d['impressions'] is num) ? (d['impressions'] as num).toInt() : 0;
        if (!byPlatform.containsKey(platform)) byPlatform[platform] = {'platform': platform, 'revenue': 0.0, 'impressions': 0};
        byPlatform[platform]!['revenue'] = (byPlatform[platform]!['revenue'] as num) + rev;
        byPlatform[platform]!['impressions'] = (byPlatform[platform]!['impressions'] as int) + imp;
      }
    }
    return byPlatform.entries
        .where((e) => e.key != '__all__')
        .map((e) => {'platform': e.key, 'revenue': e.value['revenue'], 'impressions': e.value['impressions']})
        .toList()
      ..sort((a, b) => (b['revenue'] as num).compareTo(a['revenue'] as num));
  }

  /// Una página de detalle con filtros (para PageView unificado: swipe desde revenue va a Table).
  Widget _buildDetailPageWithFilters(String metricId, String locale) {
    final width = MediaQuery.of(context).size.width;
    final padding = width > 900 ? 24.0 : (width > 600 ? 20.0 : 12.0);
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(padding, 8, padding, 0),
            child: _buildDateFilters(),
          ),
          SizedBox(height: padding),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: padding),
            child: _buildFiltersSection(),
          ),
          const SizedBox(height: 4),
          _buildDetailPage(metricId, locale),
        ],
      ),
    );
  }

  Widget _buildDetailPage(String metricId, String locale) {
    return MetricDetailContent(
      rawRows: _rawRows,
      filters: _filters,
      prevStats: _displayPrevStats,
      metricId: metricId,
    );
  }

  Widget _buildDateFilters() {
    final compact = MediaQuery.of(context).size.width < 500;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _presetChip(AppStrings.t('preset_today', LocaleNotifier.current), DateRangePreset.today, compact),
          SizedBox(width: compact ? 4 : 8),
          _presetChip(AppStrings.t('preset_yesterday', LocaleNotifier.current), DateRangePreset.yesterday, compact),
          SizedBox(width: compact ? 4 : 8),
          _presetChip(AppStrings.t('preset_7d', LocaleNotifier.current), DateRangePreset.last7, compact),
          SizedBox(width: compact ? 4 : 8),
          _presetChip(AppStrings.t('preset_30d', LocaleNotifier.current), DateRangePreset.last30, compact),
          SizedBox(width: compact ? 4 : 8),
          _presetChip(AppStrings.t('preset_90d', LocaleNotifier.current), DateRangePreset.last90, compact),
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

  String _prevPeriodLabel(String locale) {
    switch (_displayDatePreset) {
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

  void _goToDetailTab(String metricId) {
    final idx = _metricIds.indexOf(metricId);
    if (idx < 0) return;
    setState(() {
      _currentTabIndex = 2;
      _detailsMetricIndex = idx;
    });
    _mainPageController.animateToPage(
      2 + idx,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  static const Color _heroBlueStart = Color(0xFF0D47A1);
  static const Color _heroBlueEnd = Color(0xFF1565C0);
  static const Color _heroTextPrimary = Color(0xFFFFFFFF);
  static const Color _heroTextMuted = Color(0xFFBBDEFB);

  Widget _buildMainHeroCard(String locale) {
    final s = (_displayStats ?? _stats)!;
    final showCompare = !_loading &&
        _displayDatePreset != DateRangePreset.custom &&
        (_displayPrevStats ?? _prevStats) != null;
    double? revPct;
    double? impPct;
    double? ecpmPct;
    final prev = _displayPrevStats ?? _prevStats;
    if (showCompare && prev != null) {
      if (prev.revenue > 0) {
        revPct = ((s.revenue - prev.revenue) / prev.revenue) * 100;
      }
      if (prev.impressions > 0) {
        impPct = ((s.impressions - prev.impressions) / prev.impressions) * 100;
      }
      if (prev.ecpm > 0) {
        ecpmPct = ((s.ecpm - prev.ecpm) / prev.ecpm) * 100;
      }
    }
    final prevLabel = _prevPeriodLabel(locale);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_heroBlueStart, _heroBlueEnd],
          ),
        ),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppStrings.t('revenue', locale),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: _heroTextMuted,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              formatMoney(s.revenue),
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: _heroTextPrimary,
              ),
            ),
            if (revPct != null && prevLabel.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                '${revPct >= 0 ? '+' : ''}${revPct.toStringAsFixed(1)}% $prevLabel',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: revPct >= 0 ? const Color(0xFFA5D6A7) : const Color(0xFFEF9A9A),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text.rich(
                        TextSpan(
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: _heroTextMuted,
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                          children: [
                            TextSpan(text: AppStrings.t('impressions', locale)),
                            if (impPct != null && prevLabel.isNotEmpty)
                              TextSpan(
                                text: ' ${impPct >= 0 ? '+' : ''}${impPct.toStringAsFixed(1)}%',
                                style: TextStyle(
                                  color: impPct >= 0 ? const Color(0xFFA5D6A7) : const Color(0xFFEF9A9A),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        formatNumber(s.impressions),
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: _heroTextPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text.rich(
                        TextSpan(
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: _heroTextMuted,
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                          children: [
                            TextSpan(text: AppStrings.t('ecpm', locale)),
                            if (ecpmPct != null && prevLabel.isNotEmpty)
                              TextSpan(
                                text: ' ${ecpmPct >= 0 ? '+' : ''}${ecpmPct.toStringAsFixed(1)}%',
                                style: TextStyle(
                                  color: ecpmPct >= 0 ? const Color(0xFFA5D6A7) : const Color(0xFFEF9A9A),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        formatMoney(s.ecpm),
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: _heroTextPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _aggregateByCountry() {
    final byCountry = <String, Map<String, dynamic>>{};
    for (final row in _filterMetadataRows) {
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
    final selectedCountries = _filters.countries ?? [];
    if (selectedCountries.isNotEmpty) {
      for (final code in selectedCountries) {
        final key = code.trim().toUpperCase();
        if (key.isNotEmpty && !byCountry.containsKey(key)) {
          byCountry[key] = {'revenue': 0.0, 'impressions': 0};
        }
      }
    }
    return byCountry.entries
        .where((e) => e.key != '__all__')
        .map((e) => {
              'countryCode': e.key,
              'revenue': e.value['revenue'] as num,
              'impressions': e.value['impressions'] as int,
            })
        .toList()
      ..sort((a, b) => (b['revenue'] as num).compareTo(a['revenue'] as num));
  }

  /// Resumen de datos en texto para enviar a la IA (Ask AI).
  String _buildDataSummaryForAi() {
    final s = _stats!;
    final period = _displayDatePreset == DateRangePreset.last7
        ? 'Last 7 days'
        : _displayDatePreset == DateRangePreset.last30
            ? 'Last 30 days'
            : _displayDatePreset == DateRangePreset.last90
                ? 'Last 90 days'
                : _displayDatePreset == DateRangePreset.today
                    ? 'Today'
                    : _displayDatePreset == DateRangePreset.yesterday
                        ? 'Yesterday'
                        : 'Selected period';
    final buf = StringBuffer();
    buf.writeln('Period: $period');
    buf.writeln('Revenue: \$${s.revenue.toStringAsFixed(2)}');
    buf.writeln('Impressions: ${s.impressions}');
    buf.writeln('eCPM: \$${s.ecpm.toStringAsFixed(2)}');
    if (s.clicks != null) buf.writeln('Clicks: ${s.clicks}');
    if (s.completions != null) buf.writeln('Completions: ${s.completions}');
    if (s.fillRate != null) buf.writeln('Fill rate: ${s.fillRate!.toStringAsFixed(1)}%');
    if (s.completionRate != null) buf.writeln('Completion rate: ${s.completionRate!.toStringAsFixed(1)}%');
    if (s.ctr != null) buf.writeln('CTR: ${s.ctr!.toStringAsFixed(2)}%');
    final byCountry = _aggregateByCountry();
    if (byCountry.isNotEmpty) {
      buf.writeln('\nBy country:');
      for (final r in byCountry.take(30)) {
        final code = r['countryCode'] as String? ?? '';
        final name = formatCountry(code, LocaleNotifier.current);
        buf.writeln('  $name ($code): revenue \$${(r['revenue'] as num).toStringAsFixed(2)}, impressions ${r['impressions']}');
      }
    }
    return buf.toString();
  }

  /// Contenido de la tabla por país (sin Card, para usar dentro de sección colapsable).
  Widget _buildCountriesSection() {
    final byCountry = _aggregateByCountry();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
        else ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              AppStrings.t('country_table_discrepancy', LocaleNotifier.current),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: 10,
                color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ),
          ),
          Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LayoutBuilder(
                    builder: (context, c) {
                      final w = c.maxWidth;
                      final colRev = w > 400 ? 90.0 : 70.0;
                      final colImp = w > 400 ? 100.0 : 88.0;
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
                            final name = formatCountry(code, LocaleNotifier.current);
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
      ],
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              cs.primary.withValues(alpha: 0.1),
              cs.tertiary.withValues(alpha: 0.05),
            ],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => setState(() => _filtersExpanded = !_filtersExpanded),
                splashFactory: NoSplash.splashFactory,
                highlightColor: Colors.transparent,
                hoverColor: Colors.transparent,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: SizedBox(
                    height: 28,
                    width: double.infinity,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.filter_list,
                          size: 16,
                          color: cs.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          AppStrings.t('filters', LocaleNotifier.current),
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const Spacer(),
                        AnimatedRotation(
                          turns: _filtersExpanded ? 0.5 : 0,
                          duration: const Duration(milliseconds: 200),
                          child: Icon(Icons.expand_more, size: 20, color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      const dropWidth = 88.0;
                      final maxW = constraints.maxWidth;
                      if (isWide) {
                        return SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(width: dropWidth, child: _buildAppDropdown(true)),
                              const SizedBox(width: 6),
                              SizedBox(width: dropWidth, child: _buildAdUnitDropdown(true)),
                              const SizedBox(width: 6),
                              SizedBox(width: dropWidth, child: _buildPlatformDropdown(true)),
                              const SizedBox(width: 6),
                              SizedBox(width: dropWidth, child: _buildCountryDropdown(true)),
                            ],
                          ),
                        );
                      }
                      final cellW = (maxW - 6) / 2;
                      final safeW = cellW.isFinite && cellW > 0 ? cellW : 80.0;
                      return Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          SizedBox(width: safeW, child: _buildAppDropdown(true)),
                          SizedBox(width: safeW, child: _buildAdUnitDropdown(true)),
                          SizedBox(width: safeW, child: _buildPlatformDropdown(true)),
                          SizedBox(width: safeW, child: _buildCountryDropdown(true)),
                        ],
                      );
                    },
                  ),
                ),
                crossFadeState: _filtersExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 220),
                sizeCurve: Curves.easeOut,
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
    final label = selected.isEmpty || allSelected ? AppStrings.t('all', l) : (selected.length == 1 ? formatCountry(selected.single, l) : '${selected.length} ${AppStrings.t('countries_count', l)}');
    return _buildFilterChip(
      label: AppStrings.t('filter_country', l),
      valueLabel: label,
      compact: compact,
      onTap: () async {
        final allSelectedForDialog = selected.isEmpty || allSelected;
        final chosen = await _showMultiSelect(
          title: AppStrings.t('filter_country', l),
          options: options,
          labels: options.map((c) => formatCountry(c, l)).toList(),
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
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 10,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Expanded(
                  child: Text(
                    valueLabel,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 12),
                  ),
                ),
                Icon(Icons.arrow_drop_down, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
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
    for (final row in _tableRawRows) {
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

  Widget _buildDataTable(double width, {bool showHeader = true}) {
    if (_tableRawRows.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(child: Text(AppStrings.t('no_data_table', LocaleNotifier.current))),
      );
    }
    final aggregated = _aggregateRowsByDate();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showHeader) ...[
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _heroBlueStart.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.table_chart, color: _heroTextPrimary, size: 20),
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
        ],
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(
                _heroBlueStart,
              ),
              headingTextStyle: Theme.of(context).textTheme.titleSmall!.copyWith(
                color: _heroTextMuted,
                fontWeight: FontWeight.w600,
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
        ),
      ],
    );
  }
}
