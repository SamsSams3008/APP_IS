import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/error_utils.dart';
import '../../../../core/subscription/subscription_notifier.dart';
import '../../../../core/subscription/subscription_tier.dart';
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
import '../../domain/available_metrics.dart';
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
  bool _moreMetricsExpanded = false;
  bool _totalsByDayExpanded = true;
  bool _byCountryExpanded = false;
  bool _byAppExpanded = false;
  bool _byAdExpanded = false;
  bool _byPlatformExpanded = false;
  int _currentTabIndex = 0;
  int _detailsMetricIndex = 0;
  late final PageController _mainPageController = PageController();

  // Cache: por fechas + filtros (se envían a la API)
  List<IronSourceStatsRow> _cachedRawRows = [];
  List<IronSourceStatsRow> _cachedTableRawRows = [];
  String? _cachedStartDate;
  String? _cachedEndDate;
  String? _cachedFilterKey;
  Map<String, DashboardStats> _statsByNetwork = {};
  String _adSourceMetric = 'revenue'; // 'revenue' | 'impressions'
  String? _adSourceDetailNetworkId; // which network's detail card to show
  Map<String, DashboardStats> _cachedStatsByNetwork = {};

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

  /// Métricas visibles según redes seleccionadas (intersección)
  List<String> _metricIds = AvailableMetrics.baseMetricIds;

  /// Redes con credenciales; AdMob sin implementar = false
  bool _hasIronSource = false;
  bool _hasAppLovin = false;
  bool _hasAdMob = false;

  /// Redes seleccionadas ('ironSource', 'applovin', 'admob')
  Set<String> _selectedNetworks = {};

  void _onCredentialsUpdated() {
    if (!mounted) return;
    _cachedRawRows = [];
    _cachedTableRawRows = [];
    _tableRawRows = [];
    _cachedStartDate = null;
    _cachedEndDate = null;
    _cachedStatsByNetwork = {};
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
    final (valid, error) = await DashboardRepository().validateCredentialsWithError();
    if (!mounted) return;
    if (valid) {
      _load();
      return;
    }
    // Error: si es de red, NO sacar a credentials; ir a load para mostrar retry
    if (ErrorUtils.isNetworkError(error ?? '')) {
      _load(); // fallará y mostrará "sin internet" con botón reintentar
      return;
    }
    if (ErrorUtils.isKeysError(error)) {
      context.go('/credentials');
      return;
    }
    _load(); // otros errores: intentar load, mostrará el error
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
    _statsByNetwork = _cachedStatsByNetwork;
    setState(() {});
    _loadPrevStats();
  }

  Future<void> _loadPrevStats() async {
    try {
      final sel = _selectedNetworks.isEmpty ? null : _selectedNetworks;
      final prev = await _repo.getPreviousPeriodStats(_filters, selectedNetworks: sel);
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
      final providers = await _repo.getConfiguredProviders();
      final configured = <String>{
        if (providers.hasIronSource) 'ironSource',
        if (providers.hasAppLovin) 'applovin',
        if (providers.hasAdMob) 'admob',
      };
      if (configured.isEmpty && mounted) {
        setState(() {
          _loading = false;
          _error = AppStrings.t('no_network_configured', LocaleNotifier.current);
          _hasIronSource = false;
          _hasAppLovin = false;
          _hasAdMob = false;
          _selectedNetworks = {};
          _metricIds = AvailableMetrics.baseMetricIds;
        });
        return;
      }
      final sel = _selectedNetworks.isEmpty ? null : _selectedNetworks;
      final networksForStats = sel ??
          {
            if (providers.hasIronSource) 'ironSource',
            if (providers.hasAppLovin) 'applovin',
            if (providers.hasAdMob) 'admob',
          };
      final dateFilters = DashboardFilters(
        startDate: _filters.startDate,
        endDate: _filters.endDate,
        datePreset: _filters.datePreset,
      );
      final full = await _repo.getStatsRaw(_filters, selectedNetworks: sel);
      final tableFuture = _repo.getStatsRaw(dateFilters, selectedNetworks: sel);
      final metadataFuture = _repo.getFilterMetadata(dateFilters, selectedNetworks: sel);
      final statsByNetworkFuture = (networksForStats.length >= 2)
          ? _repo.getStatsByNetwork(_filters, selectedNetworks: networksForStats)
          : Future<Map<String, DashboardStats>>.value({});
      if (!mounted) return;
      _cachedRawRows = full;
      _cachedTableRawRows = await tableFuture;
      _cachedStatsByNetwork = await statsByNetworkFuture;
      _tableRawRows = _cachedTableRawRows;
      _cachedStartDate = _filters.startDateStr;
      _cachedEndDate = _filters.endDateStr;
      _cachedFilterKey = _filterKey;
      final hadNoData = _stats == null;
      _applyFiltersFromCache();
      if (mounted) {
        _hasIronSource = providers.hasIronSource;
        _hasAppLovin = providers.hasAppLovin;
        _hasAdMob = providers.hasAdMob;
        final configured = <String>{
          if (_hasIronSource) 'ironSource',
          if (_hasAppLovin) 'applovin',
          if (_hasAdMob) 'admob',
        };
        _selectedNetworks = _selectedNetworks.intersection(configured);
        if (_selectedNetworks.isEmpty) _selectedNetworks = configured;
        _metricIds = AvailableMetrics.forSelectedNetworks(_selectedNetworks);
        if (_detailsMetricIndex >= _metricIds.length) _detailsMetricIndex = 0;
        if (_selectedNetworks.length == 1) {
          try {
            _apps = await _repo.getApplications(_selectedNetworks);
          } catch (_) {
            _apps = [];
          }
        } else {
          _apps = [];
        }
      }
      try {
        _filterMetadataRows = await metadataFuture;
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _loading = false;
        _filtersExpanded = false;
        if (hadNoData) {
          _currentTabIndex = 0;
          _detailsMetricIndex = 0;
        }
        var f = _filters;
        if (_selectedNetworks.length >= 2) {
          f = f.copyWith(clearAppKeys: true, clearCountries: true, clearPlatforms: true, clearAdUnits: true);
        } else {
          if (_countryFilterOptions.isEmpty && f.hasCountryFilter) {
            f = f.copyWith(clearCountries: true);
          }
          if (_apps.isEmpty && f.hasAppFilter) {
            f = f.copyWith(clearAppKeys: true);
          }
        }
        if (f != _filters) _filters = f;
      });
      if (hadNoData) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _mainPageController.hasClients) {
            _mainPageController.jumpToPage(0);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        final err = e.toString();
        // Red primero: nunca sacar a credentials por falta de internet
        if (ErrorUtils.isNetworkError(err)) {
          setState(() {
            _error = AppStrings.t('no_internet', LocaleNotifier.current);
            _loading = false;
          });
          return;
        }
        if (ErrorUtils.isKeysError(err)) {
          context.go('/credentials');
          return;
        }
        setState(() {
          _error = err;
          _loading = false;
        });
      }
    }
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
      builder: (context, locale, _) => ValueListenableBuilder<SubscriptionTier>(
        valueListenable: SubscriptionNotifier.valueNotifier,
        builder: (context, tier, _) {
          if (tier == SubscriptionTier.basic && _currentTabIndex != 0) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && SubscriptionNotifier.current == SubscriptionTier.basic) {
                setState(() => _currentTabIndex = 0);
                _mainPageController.animateToPage(0, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
              }
            });
          }
          return Scaffold(
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
        leadingWidth: 80,
        leading: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => context.push('/subscriptions'),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    gradient: tier == SubscriptionTier.pro
                        ? const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF1D4ED8), Color(0xFF7C3AED)])
                        : null,
                    border: tier == SubscriptionTier.basic ? Border.all(color: _heroTextPrimary.withValues(alpha: 0.6), width: 1) : null,
                    boxShadow: tier == SubscriptionTier.pro ? [BoxShadow(color: const Color(0xFF1D4ED8).withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 2))] : null,
                  ),
                  child: Text(
                    tier == SubscriptionTier.basic ? AppStrings.t('tier_basic', locale) : AppStrings.t('tier_pro', locale),
                    style: const TextStyle(color: _heroTextPrimary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                  ),
                ),
              ),
            ),
          ),
        ),
        title: Text(
          _currentTabIndex == 0 ? AppStrings.t('tab_home', locale) : _currentTabIndex == 1 ? AppStrings.t('tab_table', locale) : AppStrings.t('tab_details', locale),
          style: const TextStyle(color: _heroTextPrimary, fontSize: 17),
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.settings, color: _heroTextPrimary),
            onPressed: () => context.push('/credentials'),
            tooltip: AppStrings.t('settings_tooltip', locale),
          ),
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: _buildNetworkSelector(locale),
          ),
          NavigationBar(
            selectedIndex: _currentTabIndex.clamp(0, 2),
            onDestinationSelected: (i) {
              if (i == 3) {
                context.push('/subscriptions');
                return;
              }
              if (i == 1 && !tier.hasTable) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.t('requires_pro', locale))));
                return;
              }
              if (i == 2 && !tier.hasDetails) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.t('requires_pro', locale))));
                return;
              }
              setState(() => _currentTabIndex = i);
              final targetPage = i == 0 ? 0 : i == 1 ? 1 : 2 + _detailsMetricIndex;
              final currentPage = _mainPageController.hasClients
                  ? _mainPageController.page?.round() ?? targetPage
                  : targetPage;
              final distance = (targetPage - currentPage).abs();
              if (distance > 1) {
                _mainPageController.jumpToPage(targetPage);
              } else {
                _mainPageController.animateToPage(
                  targetPage,
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeInOut,
                );
              }
            },
            destinations: [
              NavigationDestination(icon: const Icon(LucideIcons.home), selectedIcon: const Icon(LucideIcons.home), label: AppStrings.t('tab_home', locale)),
              NavigationDestination(
                icon: _navIconWithLock(LucideIcons.layoutList, tier.hasTable),
                selectedIcon: _navIconWithLock(LucideIcons.layoutList, tier.hasTable),
                label: AppStrings.t('tab_table', locale),
              ),
              NavigationDestination(
                icon: _navIconWithLock(LucideIcons.barChart2, tier.hasDetails),
                selectedIcon: _navIconWithLock(LucideIcons.barChart2, tier.hasDetails),
                label: AppStrings.t('tab_details', locale),
              ),
              NavigationDestination(icon: const Icon(Icons.workspace_premium_outlined), selectedIcon: const Icon(Icons.workspace_premium), label: AppStrings.t('tab_subscriptions', locale)),
            ],
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
                ? ErrorRetryBody(
                    message: ErrorUtils.isKeysError(_error)
                        ? AppStrings.t('invalid_keys', locale)
                        : _error!,
                    isNetworkError: ErrorUtils.isNetworkError(_error ?? ''),
                    onRetry: _load,
                  )
                : Stack(
                    children: [
                      PageView.builder(
                        controller: _mainPageController,
                        physics: const BouncingScrollPhysics(),
                        onPageChanged: (i) {
                          final tier = SubscriptionNotifier.current;
                          if (i == 1 && !tier.hasTable) {
                            _mainPageController.animateToPage(0, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
                            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.t('requires_pro', LocaleNotifier.current))));
                            return;
                          }
                          if (i >= 2 && !tier.hasDetails) {
                            _mainPageController.animateToPage(0, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
                            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.t('requires_pro', LocaleNotifier.current))));
                            return;
                          }
                          setState(() {
                            _filtersExpanded = false;
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
                        itemCount: 2 + _metricIds.length,
                        itemBuilder: (context, index) {
                          if (index == 0) return RepaintBoundary(child: _buildHomeTab(locale));
                          if (index == 1) {
                            if (!tier.hasTable) return const SizedBox.shrink();
                            return RepaintBoundary(child: _buildTableTab(locale));
                          }
                          if (!tier.hasDetails) return const SizedBox.shrink();
                          return RepaintBoundary(child: _buildDetailPageWithFilters(_metricIds[index - 2], locale));
                        },
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
                      AskAiChatBubble(dataSummary: _buildDataSummaryForAi(), isLocked: !tier.hasAi),
                    ],
                  ),
      ),
    );
        },
      ),
    );
  }

  Widget _navIconWithLock(IconData icon, bool unlocked) {
    if (unlocked) return Icon(icon);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon),
        Positioned(right: -2, top: -2, child: Icon(LucideIcons.lock, size: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ],
    );
  }

  Widget _buildHomeTab(String locale) {
    final width = MediaQuery.of(context).size.width;
    final padding = width > 900 ? 24.0 : (width > 600 ? 20.0 : 12.0);
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(padding, 20, padding, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildDateFilters(),
          SizedBox(height: padding),
          if (_stats != null) ...[
            if (_selectedNetworks.length == 1 && !_selectedNetworks.contains('applovin')) ...[
              _buildFiltersSection(),
              SizedBox(height: padding),
            ],
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              child: _buildMainHeroCard(locale),
            ),
            SizedBox(height: padding),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              child: Column(
                key: ValueKey(_metricIds.join(',')),
                children: _buildSecondaryCardsList(locale),
              ),
            ),
            if (_selectedNetworks.length >= 2 && _statsByNetwork.isNotEmpty) ...[
              SizedBox(height: padding),
              _buildAdSourcePieChart(locale),
            ],
            if (SubscriptionNotifier.current == SubscriptionTier.basic) ...[
              SizedBox(height: padding),
              _buildCollapsibleSection(
                title: AppStrings.t('totals_by_day', LocaleNotifier.current),
                expanded: _totalsByDayExpanded,
                onToggle: () => setState(() => _totalsByDayExpanded = !_totalsByDayExpanded),
                child: _buildTotalsByDayTable(MediaQuery.of(context).size.width),
              ),
            ],
          ],
        ],
      ),
    );
  }

  static const Map<String, Color> _metricColors = {
    'revenue': Color(0xFF60A5FA),
    'impressions': Color(0xFFA78BFA),
    'ecpm': Color(0xFF34D399),
    'clicks': Color(0xFFF472B6),
  };

  List<Widget> _buildSecondaryCardsList(String locale) {
    final s = _stats!;
    final l = LocaleNotifier.current;
    final primaryMetrics = [
      if (_metricIds.contains('revenue')) ('revenue', AppStrings.t('revenue', l), formatMoney(s.revenue)),
      if (_metricIds.contains('impressions')) ('impressions', AppStrings.t('impressions', l), formatNumber(s.impressions)),
      if (_metricIds.contains('ecpm')) ('ecpm', AppStrings.t('ecpm', l), formatMoney(s.ecpm)),
      if (_metricIds.contains('clicks')) ('clicks', AppStrings.t('clicks', l), formatNumber(s.clicks ?? 0)),
    ];
    final gridItems = primaryMetrics.take(4).map((m) => _buildMetricCard(m.$1, m.$2, m.$3)).toList();
    if (gridItems.isEmpty) return [];
    final rest = <Widget>[];
    if (_metricIds.contains('completions')) rest.add(_buildSecondaryCardRow(AppStrings.t('completions', l), formatNumber(s.completions ?? 0), 'completions'));
    if (_metricIds.contains('fill_rate')) rest.add(_buildSecondaryCardRow(AppStrings.t('fill_rate', l), s.fillRate != null ? '${formatDecimal(s.fillRate!)}%' : '-', 'fill_rate'));
    if (_metricIds.contains('completion_rate')) rest.add(_buildSecondaryCardRow(AppStrings.t('completion_rate', l), s.completionRate != null ? '${formatDecimal(s.completionRate!)}%' : '-', 'completion_rate'));
    if (_metricIds.contains('revenue_per_completion')) rest.add(_buildSecondaryCardRow(AppStrings.t('revenue_per_completion', l), s.revenuePerCompletion != null ? formatMoney(s.revenuePerCompletion!) : '-', 'revenue_per_completion'));
    if (_metricIds.contains('ctr')) rest.add(_buildSecondaryCardRow(AppStrings.t('ctr', l), s.ctr != null ? '${formatDecimal(s.ctr!)}%' : '-', 'ctr'));
    if (_metricIds.contains('app_requests')) rest.add(_buildSecondaryCardRow(AppStrings.t('app_requests', l), formatNumber(s.appRequests ?? 0), 'app_requests'));
    if (_metricIds.contains('dau')) rest.add(_buildSecondaryCardRow(AppStrings.t('dau', l), formatNumber(s.dau ?? 0), 'dau'));
    if (_metricIds.contains('sessions')) rest.add(_buildSecondaryCardRow(AppStrings.t('sessions', l), formatNumber(s.sessions ?? 0), 'sessions'));
    final width = MediaQuery.of(context).size.width;
    final isNarrow = width < 420;
    const crossAxisCount = 2;
    final aspectRatio = isNarrow ? 1.95 : 2.15;
    return [
      if (gridItems.isNotEmpty)
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: aspectRatio,
          children: gridItems,
        ),
      if (rest.isNotEmpty) ...[
        const SizedBox(height: 10),
        _buildCollapsibleSection(
          title: AppStrings.t('more_metrics', l),
          expanded: _moreMetricsExpanded,
          onToggle: () => setState(() => _moreMetricsExpanded = !_moreMetricsExpanded),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: rest,
          ),
        ),
      ],
    ];
  }

  List<double> _sparklineValuesForMetric(String metricId) {
    final byDate = <String, Map<String, num>>{};
    for (final row in _rawRows) {
      final date = row.date ?? '';
      if (date.isEmpty) continue;
      if (!byDate.containsKey(date)) {
        byDate[date] = {'rev': 0.0, 'imp': 0, 'clicks': 0, 'comp': 0, 'fr': 0.0, 'frN': 0, 'cr': 0.0, 'crN': 0, 'ctr': 0.0, 'ctrN': 0, 'rpc': 0.0, 'rpcN': 0};
      }
      final acc = byDate[date]!;
      for (final d in row.data ?? []) {
        final rev = _rev(d);
        final imp = (d['impressions'] is num) ? (d['impressions'] as num).toInt() : 0;
        acc['rev'] = (acc['rev'] as num) + rev;
        acc['imp'] = (acc['imp'] as num) + imp;
        acc['clicks'] = (acc['clicks'] as num) + ((d['clicks'] is num) ? (d['clicks'] as num).toInt() : 0);
        acc['comp'] = (acc['comp'] as num) + ((d['completions'] is num) ? (d['completions'] as num).toInt() : 0);
        final fr = (d['appFillRate'] is num) ? (d['appFillRate'] as num).toDouble() : 0.0;
        if (fr > 0) { acc['fr'] = (acc['fr'] as num) + fr; acc['frN'] = (acc['frN'] as num) + 1; }
        final cr = (d['completionRate'] is num) ? (d['completionRate'] as num).toDouble() : 0.0;
        if (cr > 0) { acc['cr'] = (acc['cr'] as num) + cr; acc['crN'] = (acc['crN'] as num) + 1; }
        final ctr = (d['clickThroughRate'] is num) ? (d['clickThroughRate'] as num).toDouble() : 0.0;
        if (ctr > 0) { acc['ctr'] = (acc['ctr'] as num) + ctr; acc['ctrN'] = (acc['ctrN'] as num) + 1; }
        final rpc = (d['revenuePerCompletion'] is num) ? (d['revenuePerCompletion'] as num).toDouble() : 0.0;
        if (rpc > 0) { acc['rpc'] = (acc['rpc'] as num) + rpc; acc['rpcN'] = (acc['rpcN'] as num) + 1; }
      }
    }
    final sorted = byDate.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    return sorted.map((e) {
      final d = e.value;
      switch (metricId) {
        case 'revenue': return (d['rev'] as num).toDouble();
        case 'impressions': return (d['imp'] as num).toDouble();
        case 'ecpm':
          final imp = d['imp'] as num;
          return imp > 0 ? ((d['rev'] as num) / imp * 1000) : 0.0;
        case 'clicks': return (d['clicks'] as num).toDouble();
        default: return (d['rev'] as num).toDouble();
      }
    }).toList();
  }

  Widget _buildMetricCard(String metricId, String label, String value) {
    final color = _metricColors[metricId] ?? Theme.of(context).colorScheme.primary;
    final prev = _displayPrevStats ?? _prevStats;
    double? pct;
    if (prev != null && !_loading) {
      final s = _stats!;
      if (metricId == 'revenue' && prev.revenue > 0) pct = ((s.revenue - prev.revenue) / prev.revenue) * 100;
      if (metricId == 'impressions' && prev.impressions > 0) pct = ((s.impressions - prev.impressions) / prev.impressions) * 100;
      if (metricId == 'ecpm' && prev.ecpm > 0) pct = ((s.ecpm - prev.ecpm) / prev.ecpm) * 100;
      if (metricId == 'clicks' && (prev.clicks ?? 0) > 0) pct = (((s.clicks ?? 0) - (prev.clicks ?? 0)) / (prev.clicks ?? 1)) * 100;
    }
    final sparkValues = _sparklineValuesForMetric(metricId);
    final w = MediaQuery.of(context).size.width;
    final compact = w < 420;
    final padH = compact ? 10.0 : 14.0;
    final padV = compact ? 8.0 : 12.0;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _goToDetailTab(metricId),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: EdgeInsets.fromLTRB(padH, padV, padH, padV),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: Theme.of(context).colorScheme.surface,
            border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.15)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: compact ? 2 : 4),
              Text(
                value,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: compact ? 15 : 17,
                  letterSpacing: -0.5,
                  color: color,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: compact ? 4 : 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (pct != null)
                    Text(
                      '${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: compact ? 10 : 11,
                        fontWeight: FontWeight.w700,
                        color: pct >= 0 ? _accentGreen : _accentRed,
                      ),
                    ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: SizedBox(
                        height: compact ? 18 : 22,
                        child: sparkValues.length >= 2
                            ? _SparklinePreview(values: sparkValues, color: color)
                            : const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSecondaryCardRow(String title, String value, String metricId) {
    final color = _metricColors[metricId] ?? Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _goToDetailTab(metricId),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Theme.of(context).colorScheme.surface,
              border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(title, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: color)),
                    ],
                  ),
                ),
                Icon(LucideIcons.chevronRight, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }

  double _adSourceMetricValue(DashboardStats st) {
    return _adSourceMetric == 'impressions' ? st.impressions.toDouble() : st.revenue;
  }

  String _adSourceMetricFormatted(DashboardStats st) {
    return _adSourceMetric == 'impressions' ? formatNumber(st.impressions) : formatMoney(st.revenue);
  }

  String _adSourceMetricLabel(String locale) {
    return _adSourceMetric == 'impressions' ? AppStrings.t('impressions', locale) : AppStrings.t('revenue', locale);
  }

  String _adSourceOfTotalLabel(String locale) {
    return _adSourceMetric == 'impressions' ? AppStrings.t('of_total_impressions', locale) : AppStrings.t('of_total_revenue', locale);
  }

  Widget _buildAdSourcePieChart(String locale) {
    final l = LocaleNotifier.current;
    final width = MediaQuery.of(context).size.width;
    const order = ['ironSource', 'applovin', 'admob'];
    final perNetworkAll = order
        .where((id) => _statsByNetwork.containsKey(id))
        .map((id) {
          final st = _statsByNetwork[id]!;
          final value = _adSourceMetricValue(st);
          final colors = _networkGradients[id];
          final color = colors?.first ?? Theme.of(context).colorScheme.primary;
          return (id: id, stats: st, value: value, color: color);
        })
        .toList();
    final total = perNetworkAll.fold<double>(0, (s, e) => s + e.value);
    if (perNetworkAll.isEmpty) return const SizedBox.shrink();
    final perNetworkForChart = perNetworkAll.where((e) => e.value > 0).toList();

    final detailId = (_adSourceDetailNetworkId != null && perNetworkAll.any((e) => e.id == _adSourceDetailNetworkId))
        ? _adSourceDetailNetworkId!
        : perNetworkAll.first.id;
    if (_adSourceDetailNetworkId != detailId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _adSourceDetailNetworkId = detailId);
      });
    }

    String networkLabel(String id) {
      switch (id) {
        case 'ironSource': return AppStrings.t('ironsource_section', l);
        case 'applovin': return 'AppLovin MAX';
        case 'admob': return AppStrings.t('admob_label', l);
        default: return id;
      }
    }

    final chartSize = width < 400 ? 88.0 : (width < 500 ? 100.0 : 112.0);
    final radius = (chartSize / 2) - 2;
    final sections = perNetworkForChart
        .map(
          (e) => PieChartSectionData(
            value: e.value,
            title: '',
            color: e.color,
            radius: radius,
            badgePositionPercentageOffset: 0,
          ),
        )
        .toList();

    final detailEntry = perNetworkAll.firstWhere((e) => e.id == detailId);
    final detailPct = total > 0 ? (detailEntry.value / total) * 100 : 0.0;
    final cs = Theme.of(context).colorScheme;
    final gradient = _networkGradients[detailId];

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: cs.surface,
        border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            AppStrings.t('ad_networks', l).toUpperCase(),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: ['revenue', 'impressions'].map((m) {
              final selected = _adSourceMetric == m;
              final label = m == 'revenue' ? AppStrings.t('revenue', l) : AppStrings.t('impressions', l);
              return ChoiceChip(
                label: Text(label, style: TextStyle(fontSize: 11, fontWeight: selected ? FontWeight.w600 : FontWeight.w500)),
                selected: selected,
                onSelected: (_) => setState(() => _adSourceMetric = m),
                showCheckmark: false,
                labelPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                backgroundColor: cs.surfaceContainerHighest,
                selectedColor: cs.primary.withValues(alpha: 0.2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: chartSize + 8,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ClipOval(
                  child: SizedBox(
                    width: chartSize,
                    height: chartSize,
                    child: perNetworkForChart.isEmpty
                    ? Center(
                        child: Icon(LucideIcons.pieChart, size: chartSize * 0.4, color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
                      )
                    : PieChart(
                        PieChartData(
                          sections: sections,
                          sectionsSpace: 1,
                          centerSpaceRadius: 0,
                        ),
                      ),
                  ),
                ),
                const SizedBox(width: 28),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: perNetworkAll.map((e) {
                    final pct = total > 0 ? (e.value / total) * 100 : 0.0;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: e.color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            networkLabel(e.id),
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${pct.toStringAsFixed(0)}%',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
          const SizedBox(height: 10),
          Row(
            children: perNetworkAll.map((e) {
              final selected = e.id == detailId;
              final grad = _networkGradients[e.id];
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => setState(() => _adSourceDetailNetworkId = e.id),
                      borderRadius: BorderRadius.circular(8),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: 32,
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          gradient: selected && grad != null
                              ? LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: grad)
                              : null,
                          color: selected && grad == null ? cs.primaryContainer : cs.surfaceContainerHighest,
                        ),
                        child: Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              e.id == 'applovin' ? 'AppLovin' : networkLabel(e.id),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: selected ? Colors.white : cs.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
              border: Border.all(color: cs.outline.withValues(alpha: 0.15)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _adSourceMetricLabel(l),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                    Text(
                      _adSourceMetricFormatted(detailEntry.stats),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: detailEntry.color),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (detailPct / 100).clamp(0.0, 1.0),
                    minHeight: 6,
                    backgroundColor: cs.surface,
                    valueColor: AlwaysStoppedAnimation<Color>(gradient?.first ?? detailEntry.color),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${detailPct.toStringAsFixed(0)}% ${_adSourceOfTotalLabel(l)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableTab(String locale) {
    final width = MediaQuery.of(context).size.width;
    final padding = width > 900 ? 24.0 : (width > 600 ? 20.0 : 12.0);
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(padding, 20, padding, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildDateFilters(),
          SizedBox(height: padding),
          if (_stats != null) ...[
            _buildCollapsibleSection(
              title: AppStrings.t('totals_by_day', LocaleNotifier.current),
              expanded: _totalsByDayExpanded,
              onToggle: () => setState(() => _totalsByDayExpanded = !_totalsByDayExpanded),
              child: _buildTotalsByDayTable(width),
            ),
            if (_selectedNetworks.contains('ironSource') && !_selectedNetworks.contains('applovin')) ...[
              SizedBox(height: padding),
              ..._buildBreakdownTables(width, locale),
            ],
          ],
        ],
      ),
    );
  }

  static const double _networkChipHeight = 44;

  Widget _buildNetworkSelector(String locale) {
    final l = LocaleNotifier.current;
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 6.0;
        return SizedBox(
          height: _networkChipHeight,
          child: Row(
            children: [
              Expanded(child: Center(child: _buildNetworkChip('ironSource', AppStrings.t('ironsource_section', l), _hasIronSource))),
              SizedBox(width: gap),
              Expanded(child: Center(child: _buildNetworkChip('applovin', AppStrings.t('applovin_section', l), _hasAppLovin))),
              SizedBox(width: gap),
              Expanded(child: Center(child: _buildNetworkChip('admob', AppStrings.t('admob_label', l), _hasAdMob))),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNetworkChip(String id, String label, bool hasKey) {
    final selected = _selectedNetworks.contains(id);
    final enabled = hasKey;
    final cs = Theme.of(context).colorScheme;
    final section = id == 'ironSource' ? 'ironsource' : id.toLowerCase();
    final gradient = _networkGradients[id];
    final chip = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled
            ? () {
                final next = selected ? _selectedNetworks.where((x) => x != id).toSet() : {..._selectedNetworks, id};
                if (next.isEmpty) return;
                setState(() {
                  _selectedNetworks = next;
                  _metricIds = AvailableMetrics.forSelectedNetworks(_selectedNetworks);
                  if (_detailsMetricIndex >= _metricIds.length) _detailsMetricIndex = 0;
                  _cachedRawRows = [];
                  _cachedTableRawRows = [];
                  _tableRawRows = [];
                  _cachedStartDate = null;
                  _cachedEndDate = null;
                  _cachedStatsByNetwork = {};
                });
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _load();
                });
              }
            : null,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          height: _networkChipHeight,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: selected && gradient != null
                ? LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: gradient)
                : null,
            color: selected && gradient == null ? cs.primaryContainer : (enabled ? cs.surfaceContainerHighest : cs.surfaceContainerHighest.withValues(alpha: 0.6)),
            boxShadow: selected && gradient != null
                ? [BoxShadow(color: gradient.first.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4))]
                : null,
          ),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                id == 'applovin' ? 'AppLovin' : label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : cs.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    if (enabled) return chip;
    return GestureDetector(
      onTap: () => context.push('/credentials?section=$section'),
      child: AbsorbPointer(child: chip),
    );
  }

  Widget _buildTotalsByDayTable(double width) {
    return _buildDataTable(width, showHeader: false);
  }

  List<Widget> _buildBreakdownTables(double width, String locale) {
    final l = LocaleNotifier.current;
    final padding = width > 900 ? 24.0 : (width > 600 ? 20.0 : 12.0);
    return [
      _buildCollapsibleSection(
        title: AppStrings.t('by_country', l),
        expanded: _byCountryExpanded,
        onToggle: () => setState(() => _byCountryExpanded = !_byCountryExpanded),
        child: _buildCountriesSection(width),
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
    ];
  }

  Widget _buildCollapsibleSection({
    required String title,
    required bool expanded,
    required VoidCallback onToggle,
    required Widget child,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: cs.surface,
        border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
      ),
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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                    const Spacer(),
                    AnimatedRotation(
                      turns: expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(LucideIcons.chevronDown, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
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

  Widget _buildCountriesSection(double width) {
    final byCountry = _aggregateByCountry();
    final l = LocaleNotifier.current;
    if (byCountry.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(AppStrings.t('no_country_data', l), style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      );
    }
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final colRev = w > 400 ? 90.0 : 70.0;
        final colImp = w > 400 ? 100.0 : 88.0;
        final colCountry = w - colRev - colImp - 16;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                AppStrings.t('country_table_discrepancy', l),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.6)),
              ),
            ),
            ...byCountry.take(12).map((r) {
              final code = r['countryCode'] as String?;
              final name = formatCountry(code, LocaleNotifier.current);
              final rev = (r['revenue'] as num).toDouble();
              final imp = r['impressions'] as int;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    SizedBox(width: colCountry, child: Text(name, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    SizedBox(width: colRev, child: Text(formatMoney(rev), style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.primary), textAlign: TextAlign.end, overflow: TextOverflow.ellipsis)),
                    SizedBox(width: colImp, child: Text(formatNumber(imp), style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.end, overflow: TextOverflow.ellipsis)),
                  ],
                ),
              );
            }),
          ],
        );
      },
    );
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
    return _buildGenericTable(rows: byApp.take(12).toList(), labelKey: 'appKey', labelFormatter: (v) => _appKeyToName(v));
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
    return _buildGenericTable(rows: byAd.take(12).toList(), labelKey: 'adUnit', labelFormatter: (v) => adLabels[v ?? ''] ?? (v ?? '-'));
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
    return _buildGenericTable(rows: byPlatform.take(12).toList(), labelKey: 'platform', labelFormatter: (v) => platformLabels[v ?? ''] ?? (v ?? '-'));
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
        final labelStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500, fontSize: smallFont ? 11 : null);
        final numStyle = Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: smallFont ? 10 : null);
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
    return byApp.entries.where((e) => e.key != '__all__').map((e) => {'appKey': e.key, 'revenue': e.value['revenue'], 'impressions': e.value['impressions']}).toList()
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
    return byAd.entries.map((e) => {'adUnit': e.key, 'revenue': e.value['revenue'], 'impressions': e.value['impressions']}).toList()
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
    return byPlatform.entries.where((e) => e.key != '__all__').map((e) => {'platform': e.key, 'revenue': e.value['revenue'], 'impressions': e.value['impressions']}).toList()
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
            padding: EdgeInsets.fromLTRB(padding, 20, padding, 0),
            child: _buildDateFilters(),
          ),
          if (SubscriptionNotifier.current.hasFilters && _selectedNetworks.length == 1 && !_selectedNetworks.contains('applovin')) ...[
            SizedBox(height: padding),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: padding),
              child: _buildFiltersSection(),
            ),
          ],
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
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _pickDateRange,
              borderRadius: BorderRadius.circular(20),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 14, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: _filters.datePreset == DateRangePreset.custom
                      ? const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF1D4ED8), Color(0xFF7C3AED)])
                      : null,
                  color: _filters.datePreset == DateRangePreset.custom ? null : Theme.of(context).colorScheme.surfaceContainerHighest,
                  boxShadow: _filters.datePreset == DateRangePreset.custom ? [BoxShadow(color: const Color(0xFF1D4ED8).withOpacity(0.25), blurRadius: 12, offset: const Offset(0, 4))] : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.calendar, size: 14, color: _filters.datePreset == DateRangePreset.custom ? Colors.white : Theme.of(context).colorScheme.onSurfaceVariant),
                    const SizedBox(width: 6),
                    Text(
                      compact ? AppStrings.t('filter_date', LocaleNotifier.current) : AppStrings.t('filter_custom', LocaleNotifier.current),
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _filters.datePreset == DateRangePreset.custom ? Colors.white : Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _presetChip(String label, DateRangePreset preset, bool compact) {
    final selected = _filters.datePreset == preset;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _applyPreset(preset),
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: selected
                ? const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF1D4ED8), Color(0xFF7C3AED)])
                : null,
            color: selected ? null : Theme.of(context).colorScheme.surfaceContainerHighest,
            boxShadow: selected ? [BoxShadow(color: const Color(0xFF1D4ED8).withOpacity(0.25), blurRadius: 12, offset: const Offset(0, 4))] : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
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
    if (!SubscriptionNotifier.current.hasDetails) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.t('requires_pro', LocaleNotifier.current))),
      );
      return;
    }
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

  static const Color _heroBlueStart = Color(0xFF0F2460);
  static const Color _heroBlueEnd = Color(0xFF1A1060);
  static const Color _heroTextPrimary = Color(0xFFFFFFFF);
  static const Color _heroTextMuted = Color(0xFF93C5FD);
  static const Color _accentGreen = Color(0xFF22C55E);
  static const Color _accentRed = Color(0xFFF97373);

  static const Map<String, List<Color>> _networkGradients = {
    'ironSource': [Color(0xFFFF6B35), Color(0xFFFF3D00)],
    'applovin': [Color(0xFF00C6FF), Color(0xFF0072FF)],
    'admob': [Color(0xFF34D399), Color(0xFF059669)],
  };

  Widget _buildMainHeroCard(String locale) {
    final s = (_displayStats ?? _stats)!;
    final showCompare = !_loading &&
        _displayDatePreset != DateRangePreset.custom &&
        (_displayPrevStats ?? _prevStats) != null;
    double? revPct;
    final prev = _displayPrevStats ?? _prevStats;
    if (showCompare && prev != null && prev.revenue > 0) {
      revPct = ((s.revenue - prev.revenue) / prev.revenue) * 100;
    }
    final prevLabel = _prevPeriodLabel(locale);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_heroBlueStart, _heroBlueEnd],
        ),
        border: Border.all(color: const Color(0xFF1D4ED8).withOpacity(0.25), width: 1),
        boxShadow: [
          BoxShadow(color: const Color(0xFF1D4ED8).withOpacity(0.2), blurRadius: 16, offset: const Offset(0, 4)),
        ],
      ),
      child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'TOTAL REVENUE',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5, color: _heroTextMuted),
            ),
            const SizedBox(height: 6),
            Text(
              formatMoney(s.revenue),
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                letterSpacing: -1,
                height: 1,
                color: _heroTextPrimary,
              ),
            ),
            if (revPct != null && prevLabel.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (revPct >= 0 ? _accentGreen : _accentRed).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${revPct >= 0 ? '↑' : '↓'} ${revPct.abs().toStringAsFixed(1)}% vs $prevLabel',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: revPct >= 0 ? _accentGreen : _accentRed),
                ),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        AppStrings.t('impressions', locale),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: _heroTextMuted, fontWeight: FontWeight.w500, fontSize: 11),
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
                Container(width: 1, height: 36, margin: const EdgeInsets.symmetric(horizontal: 8), color: const Color(0xFF1E3A8A)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        AppStrings.t('ecpm', locale),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: _heroTextMuted, fontWeight: FontWeight.w500, fontSize: 11),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        formatMoney(s.ecpm),
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700, fontSize: 18, color: _heroTextPrimary),
                      ),
                    ],
                  ),
                ),
                Container(width: 1, height: 36, margin: const EdgeInsets.symmetric(horizontal: 8), color: const Color(0xFF1E3A8A)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        AppStrings.t('clicks', locale),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: _heroTextMuted, fontWeight: FontWeight.w500, fontSize: 11),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        formatNumber(s.clicks ?? 0),
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700, fontSize: 18, color: _heroTextPrimary),
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

  /// Solo países que aparecen en los datos de la(s) red(es) seleccionada(s).
  List<String> get _countryFilterOptions {
    final set = <String>{};
    for (final row in _filterMetadataRows) {
      final c = (row.country ?? '').trim().toUpperCase();
      if (c.isNotEmpty) set.add(c);
    }
    return set.toList()..sort();
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
                          LucideIcons.filter,
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
                          child: Icon(LucideIcons.chevronDown, size: 20, color: cs.onSurfaceVariant),
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
        if (apps.isEmpty) {
          if (!mounted) return;
          final msg = _selectedNetworks.length == 1 && _selectedNetworks.contains('admob')
              ? AppStrings.t('no_apps_configured_admob', l)
              : AppStrings.t('no_apps_detected', l);
          await showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(AppStrings.t('app_filter', l)),
              content: Text(msg),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
          return;
        }
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
          if (!SubscriptionNotifier.current.hasFilters && !all) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.t('requires_pro_filters', LocaleNotifier.current))));
            return;
          }
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
          if (!SubscriptionNotifier.current.hasFilters && !all) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.t('requires_pro_filters', LocaleNotifier.current))));
            return;
          }
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
          if (!SubscriptionNotifier.current.hasFilters && !all) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.t('requires_pro_filters', LocaleNotifier.current))));
            return;
          }
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
        if (options.isEmpty) {
          if (!mounted) return;
          await showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(AppStrings.t('filter_country', l)),
              content: Text(AppStrings.t('no_country_filter_available', l)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
          return;
        }
        final allSelectedForDialog = selected.isEmpty || allSelected;
        final chosen = await _showMultiSelect(
          title: AppStrings.t('filter_country', l),
          options: options,
          labels: options.map((c) => formatCountry(c, l)).toList(),
          selected: allSelectedForDialog ? options.toSet() : selected.toSet(),
        );
        if (chosen != null && mounted) {
          final all = chosen.isEmpty || chosen.length >= options.length;
          if (!SubscriptionNotifier.current.hasFilters && !all) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.t('requires_pro_filters', LocaleNotifier.current))));
            return;
          }
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
                Icon(LucideIcons.chevronDown, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
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
    final l = LocaleNotifier.current;
    return aggregated.map((r) {
      final cells = <DataCell>[
        DataCell(Tooltip(message: r['date'] as String, child: Text(r['date'] as String))),
      ];
      for (final mid in _metricIds) {
        cells.add(DataCell(_cell(_formatTableCell(r, mid, l))));
      }
      return DataRow(cells: cells);
    }).toList();
  }

  String _metricLabel(String metricId) {
    final l = LocaleNotifier.current;
    switch (metricId) {
      case 'revenue': return AppStrings.t('income', l);
      case 'impressions': return AppStrings.t('impressions', l);
      case 'ecpm': return AppStrings.t('ecpm', l);
      case 'clicks': return AppStrings.t('clicks', l);
      case 'completions': return AppStrings.t('completions', l);
      case 'fill_rate': return AppStrings.t('fill_rate', l);
      case 'completion_rate': return AppStrings.t('completion_rate', l);
      case 'revenue_per_completion': return AppStrings.t('rev_comp', l);
      case 'ctr': return AppStrings.t('ctr', l);
      case 'app_requests': return AppStrings.t('app_requests', l);
      case 'dau': return AppStrings.t('dau', l);
      case 'sessions': return AppStrings.t('sessions', l);
      default: return metricId;
    }
  }

  String _formatTableCell(Map<String, dynamic> r, String metricId, String l) {
    switch (metricId) {
      case 'revenue':
        return formatMoney((r['revenue'] as num?)?.toDouble() ?? 0);
      case 'impressions':
        return formatNumber(r['impressions'] as int? ?? 0);
      case 'ecpm':
        return formatMoney((r['eCPM'] as num?)?.toDouble() ?? 0);
      case 'clicks':
        final v = r['clicks'] as int?;
        return v != null ? formatNumber(v) : '—';
      case 'completions':
        final v = r['completions'] as int?;
        return v != null ? formatNumber(v) : '—';
      case 'fill_rate':
        final v = r['fillRate'] as double?;
        return v != null ? '${formatDecimal(v)}%' : '—';
      case 'completion_rate':
        final v = r['completionRate'] as double?;
        return v != null ? '${formatDecimal(v)}%' : '—';
      case 'revenue_per_completion':
        final v = r['revenuePerCompletion'] as double?;
        return v != null ? formatMoney(v) : '—';
      case 'ctr':
        final v = r['ctr'] as double?;
        return v != null ? '${formatDecimal(v)}%' : '—';
      case 'app_requests':
        final v = r['appRequests'] as int?;
        return v != null ? formatNumber(v) : '—';
      case 'dau':
        final v = r['dau'] as int?;
        return v != null ? formatNumber(v) : '—';
      case 'sessions':
        final v = r['sessions'] as int?;
        return v != null ? formatNumber(v) : '—';
      default:
        return '—';
    }
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
                child: Icon(LucideIcons.layoutList, color: _heroTextPrimary, size: 20),
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
                ..._metricIds.map((mid) => DataColumn(
                  label: Text(_metricLabel(mid), overflow: TextOverflow.ellipsis),
                  numeric: true,
                )),
              ],
              rows: _dataTableRows(aggregated),
            ),
          ),
        ),
      ],
    );
  }
}

class _SparklinePreview extends StatelessWidget {
  const _SparklinePreview({required this.values, required this.color});

  final List<double> values;
  final Color color;

  static const double _inset = 3;

  @override
  Widget build(BuildContext context) {
    if (values.length < 2) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (_, c) {
        final w = c.maxWidth;
        final h = c.maxHeight;
        if (w <= _inset * 2 || h <= _inset * 2) return const SizedBox.shrink();
        return CustomPaint(
          size: Size(w, h),
          painter: _SparklinePainter(
            values: values,
            color: color,
            inset: _inset,
          ),
        );
      },
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({required this.values, required this.color, this.inset = 3});

  final List<double> values;
  final Color color;
  final double inset;

  @override
  void paint(Canvas canvas, Size size) {
    final min = values.reduce((a, b) => a < b ? a : b);
    final max = values.reduce((a, b) => a > b ? a : b);
    final range = (max - min).clamp(0.01, double.infinity);
    final w = size.width;
    final h = size.height;
    final left = inset;
    final right = w - inset;
    final top = inset;
    final bottom = h - inset;
    final innerW = (right - left).clamp(1.0, double.infinity);
    final innerH = (bottom - top).clamp(1.0, double.infinity);
    final pts = <Offset>[];
    for (var i = 0; i < values.length; i++) {
      final t = values.length > 1 ? i / (values.length - 1) : 0.0;
      final x = left + t * innerW;
      final yNorm = range > 0 ? (values[i] - min) / range : 0.0;
      final y = bottom - yNorm * innerH;
      pts.add(Offset(x.clamp(left, right), y.clamp(top, bottom)));
    }
    if (pts.isEmpty) return;
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < pts.length; i++) {
      path.lineTo(pts[i].dx, pts[i].dy);
    }
    canvas.drawPath(path, linePaint);
    final fillPath = Path.from(path)
      ..lineTo(pts.last.dx, bottom)
      ..lineTo(pts.first.dx, bottom)
      ..close();
    canvas.drawPath(
      fillPath,
      Paint()
        ..color = color.withValues(alpha: 0.12)
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter old) =>
      !listEquals(values, old.values) || color != old.color;
}
