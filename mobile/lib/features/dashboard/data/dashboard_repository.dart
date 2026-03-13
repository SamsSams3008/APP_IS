import '../domain/available_metrics.dart';
import '../domain/dashboard_filters.dart';
import '../domain/dashboard_stats.dart';
import '../../../data/admob/admob_api_client.dart';
import '../../../data/applovin/applovin_api_client.dart';
import '../../../data/credentials/credentials_repository.dart';
import '../../../data/ironsource/ironsource_api_client.dart';

/// Qué proveedores tienen credenciales configuradas.
class ConfiguredProviders {
  const ConfiguredProviders({
    required this.hasIronSource,
    required this.hasAppLovin,
    this.hasAdMob = false,
  });
  final bool hasIronSource;
  final bool hasAppLovin;
  final bool hasAdMob;
  List<String> get metricIds => AvailableMetrics.forProviders(
        hasIronSource: hasIronSource,
        hasAppLovin: hasAppLovin,
        hasAdMob: hasAdMob,
      );
}

class DashboardRepository {
  DashboardRepository({
    IronSourceApiClient? ironSourceApi,
    AppLovinApiClient? appLovinApi,
    AdMobApiClient? admobApi,
    CredentialsRepository? credentialsRepo,
  })  : _ironSource = ironSourceApi ?? IronSourceApiClient(),
        _appLovin = appLovinApi ?? AppLovinApiClient(),
        _admob = admobApi ?? AdMobApiClient(),
        _credentials = credentialsRepo ?? CredentialsRepository();

  final IronSourceApiClient _ironSource;
  final AppLovinApiClient _appLovin;
  final AdMobApiClient _admob;
  final CredentialsRepository _credentials;

  static double _n(Map<String, dynamic> d, String k) =>
      (d[k] is num) ? (d[k] as num).toDouble() : 0;

  /// Agregación sin redondeos intermedios. Solo redondear al mostrar.
  static DashboardStats statsFromRows(List<IronSourceStatsRow> rows) {
    double revenue = 0, fillRateSum = 0, completionRateSum = 0, revPerCompSum = 0, ctrSum = 0;
    int impressions = 0, clicks = 0, completions = 0, appRequests = 0, dau = 0, sessions = 0;
    int fillRateCount = 0, completionRateCount = 0, revPerCompCount = 0, ctrCount = 0;
    for (final row in rows) {
      for (final d in row.data ?? []) {
        revenue += _n(d, 'revenue');
        impressions += _n(d, 'impressions').toInt();
        clicks += _n(d, 'clicks').toInt();
        completions += _n(d, 'completions').toInt();
        appRequests += _n(d, 'appRequests').toInt();
        dau += _n(d, 'dau').toInt();
        sessions += _n(d, 'sessions').toInt();
        final fr = _n(d, 'appFillRate');
        if (fr > 0) { fillRateSum += fr; fillRateCount++; }
        final cr = _n(d, 'completionRate');
        if (cr > 0) { completionRateSum += cr; completionRateCount++; }
        final rpc = _n(d, 'revenuePerCompletion');
        if (rpc > 0) { revPerCompSum += rpc; revPerCompCount++; }
        final ctr = _n(d, 'clickThroughRate');
        if (ctr > 0) { ctrSum += ctr; ctrCount++; }
      }
    }
    final ecpm = impressions > 0 ? (revenue / impressions) * 1000 : 0.0;
    return DashboardStats(
      revenue: revenue,
      impressions: impressions,
      ecpm: ecpm,
      clicks: clicks,
      completions: completions,
      completionRate: completionRateCount > 0 ? completionRateSum / completionRateCount : (impressions > 0 && completions > 0 ? (completions / impressions) * 100 : null),
      fillRate: fillRateCount > 0 ? fillRateSum / fillRateCount : null,
      revenuePerCompletion: revPerCompCount > 0 ? revPerCompSum / revPerCompCount : (completions > 0 ? revenue / completions : null),
      ctr: ctrCount > 0 ? ctrSum / ctrCount : (impressions > 0 && clicks > 0 ? (clicks / impressions) * 100 : null),
      appRequests: appRequests > 0 ? appRequests : null,
      dau: dau > 0 ? dau : null,
      sessions: sessions > 0 ? sessions : null,
    );
  }

  /// Revenue por red de anuncios (para gráfico de pastel). Fetch en paralelo.
  Future<Map<String, DashboardStats>> getStatsByNetwork(
    DashboardFilters filters, {
    Set<String>? selectedNetworks,
  }) async {
    final providers = await getConfiguredProviders();
    final sel = selectedNetworks ?? {
      if (providers.hasIronSource) 'ironSource',
      if (providers.hasAppLovin) 'applovin',
      if (providers.hasAdMob) 'admob',
    };
    final entries = await Future.wait(sel.map((net) async {
      final rows = await getStatsRaw(filters, selectedNetworks: {net});
      return MapEntry(net, statsFromRows(rows));
    }));
    return Map.fromEntries(entries.where((e) => e.value.revenue > 0 || e.value.impressions > 0));
  }

  /// Stats del periodo anterior (misma duración, días previos) para comparar %.
  Future<DashboardStats?> getPreviousPeriodStats(
    DashboardFilters filters, {
    Set<String>? selectedNetworks,
  }) async {
    final days = filters.endDate.difference(filters.startDate).inDays + 1;
    final prevEnd = filters.startDate.subtract(const Duration(days: 1));
    final prevStart = prevEnd.subtract(Duration(days: days - 1));
    final prevFilters = DashboardFilters(
      startDate: prevStart,
      endDate: prevEnd,
      datePreset: filters.datePreset,
      appKeys: filters.appKeys,
      platforms: filters.platforms,
      adUnits: filters.adUnits,
      countries: filters.countries,
    );
    try {
      final rows = await getStatsRaw(prevFilters, selectedNetworks: selectedNetworks);
      return statsFromRows(rows);
    } catch (_) {
      return null;
    }
  }

  Future<ConfiguredProviders> getConfiguredProviders() async {
    final ironsource = await _credentials.getCredentials();
    final applovin = await _credentials.getAppLovinReportKey();
    final hasAdMob = await _credentials.hasAdMobCredentials();
    return ConfiguredProviders(
      hasIronSource: ironsource != null &&
          ironsource.secretKey.trim().isNotEmpty &&
          ironsource.refreshToken.trim().isNotEmpty,
      hasAppLovin: applovin != null && applovin.trim().isNotEmpty,
      hasAdMob: hasAdMob,
    );
  }

  /// Obtiene stats desde las redes seleccionadas. [selectedNetworks]: 'ironSource', 'applovin'.
  Future<List<IronSourceStatsRow>> getStatsRaw(
    DashboardFilters filters, {
    Set<String>? selectedNetworks,
  }) async {
    final providers = await getConfiguredProviders();
    final sel = selectedNetworks ?? {
      if (providers.hasIronSource) 'ironSource',
      if (providers.hasAppLovin) 'applovin',
      if (providers.hasAdMob) 'admob',
    };
    if (sel.isEmpty) {
      throw Exception('Selecciona al menos una red o configura credenciales en Ajustes.');
    }

    final allRows = <IronSourceStatsRow>[];

    if (sel.contains('ironSource') && providers.hasIronSource) {
      final appKey = _join(filters.appKeys);
      final country = _join(filters.countries);
      final adUnits = _mapAdFormatForApi(_join(filters.adUnits));
      final platform = _platformParam(filters.platforms);
      final rows = await _ironSource.getStats(
        startDate: filters.startDateStr,
        endDate: filters.endDateStr,
        appKey: appKey,
        country: country,
        adUnits: adUnits,
        platform: platform,
        breakdowns: 'date',
        metrics: null,
      );
      allRows.addAll(rows);
    }

    if (sel.contains('applovin') && providers.hasAppLovin) {
      final country = _join(filters.countries);
      final platform = _platformParam(filters.platforms);
      final adFormat = _join(filters.adUnits);
      try {
        final rows = await _appLovin.getStats(
          startDate: filters.startDateStr,
          endDate: filters.endDateStr,
          country: country,
          platform: platform,
          adFormat: adFormat,
        );
        allRows.addAll(rows);
      } catch (e) {
        final err = e.toString().toLowerCase();
        if (err.contains('45') || err.contains('window')) {
          throw Exception('AppLovin permite máximo 45 días. Usa un rango más corto.');
        }
        rethrow;
      }
    }

    if (sel.contains('admob') && providers.hasAdMob) {
      try {
        final rows = await _admob.getStats(
          startDate: filters.startDateStr,
          endDate: filters.endDateStr,
          country: _join(filters.countries),
          platform: _platformParam(filters.platforms),
          adFormat: _join(filters.adUnits),
          appIds: filters.appKeys?.isNotEmpty == true ? filters.appKeys : null,
        );
        allRows.addAll(rows);
      } catch (_) {}
    }

    return allRows;
  }

  /// Llamada con breakdowns completos solo para obtener dimensiones.
  Future<List<IronSourceStatsRow>> getFilterMetadata(
    DashboardFilters filters, {
    Set<String>? selectedNetworks,
  }) async {
    final providers = await getConfiguredProviders();
    final sel = selectedNetworks ?? {
      if (providers.hasIronSource) 'ironSource',
      if (providers.hasAppLovin) 'applovin',
      if (providers.hasAdMob) 'admob',
    };
    final allRows = <IronSourceStatsRow>[];

    if (sel.contains('ironSource') && providers.hasIronSource) {
      final meta = await _ironSource.getStats(
        startDate: filters.startDateStr,
        endDate: filters.endDateStr,
        appKey: null,
        country: null,
        adUnits: null,
        platform: null,
        breakdowns: 'date,adFormat,platform,country,app',
        metrics: 'revenue,impressions',
      );
      allRows.addAll(meta);
    }

    if (sel.contains('applovin') && providers.hasAppLovin) {
      try {
        final meta = await _appLovin.getStats(
          startDate: filters.startDateStr,
          endDate: filters.endDateStr,
          country: null,
          platform: null,
          adFormat: null,
        );
        allRows.addAll(meta);
      } catch (_) {}
    }

    return allRows;
  }

  static String? _mapAdFormatForApi(String? adFormatCsv) {
    if (adFormatCsv == null || adFormatCsv.isEmpty) return null;
    final mapped = adFormatCsv.split(',').map((s) {
      final t = s.trim().toLowerCase();
      if (t == 'rewardedvideo') return 'rewarded';
      if (t == 'offerwall') return 'offerwall';
      if (t == 'interstitial') return 'interstitial';
      if (t == 'banner') return 'banner';
      return s.trim();
    }).where((s) => s.isNotEmpty).toList();
    return mapped.isEmpty ? null : mapped.join(',');
  }

  static String? _join(List<String>? list) {
    if (list == null || list.isEmpty) return null;
    return list.join(',');
  }

  static String? _platformParam(List<String>? platforms) {
    if (platforms == null || platforms.isEmpty) return null;
    if (platforms.length == 2) return null;
    return platforms.single.toLowerCase();
  }

  /// Apps para el filtro: según la red seleccionada (solo cuando hay una sola).
  Future<List<IronSourceApp>> getApplications(Set<String> selectedNetworks) async {
    if (selectedNetworks.length != 1) return [];
    final only = selectedNetworks.single;
    if (only == 'ironSource') {
      final providers = await getConfiguredProviders();
      if (providers.hasIronSource) return _ironSource.getApplications();
      return [];
    }
    if (only == 'admob') {
      final providers = await getConfiguredProviders();
      if (providers.hasAdMob) return _admob.getApps();
      return [];
    }
    return [];
  }

  /// Valida IronSource (usa credenciales guardadas).
  Future<bool> validateIronSource() async {
    try {
      await _ironSource.getApplications();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Valida AppLovin (usa Report Key guardado).
  Future<bool> validateAppLovin() async {
    try {
      return await _appLovin.validateReportKey();
    } catch (_) {
      return false;
    }
  }

  /// Valida AdMob (usa Publisher ID + OAuth refresh token).
  Future<bool> validateAdMob() async {
    try {
      return await _admob.validateCredentials();
    } catch (_) {
      return false;
    }
  }

  /// Valida que al menos un proveedor configurado funcione.
  Future<(bool valid, String? error)> validateCredentialsWithError() async {
    final providers = await getConfiguredProviders();
    if (!providers.hasIronSource && !providers.hasAppLovin && !providers.hasAdMob) {
      return (false, 'Configura IronSource, AppLovin o AdMob en Ajustes.');
    }
    String? lastError;
    if (providers.hasIronSource) {
      try {
        await _ironSource.getApplications();
        return (true, null);
      } catch (e) {
        lastError = e.toString();
      }
    }
    if (providers.hasAppLovin) {
      try {
        final ok = await _appLovin.validateReportKey();
        if (ok) return (true, null);
        lastError = lastError ?? 'AppLovin Report Key inválido.';
      } catch (e) {
        lastError = lastError ?? e.toString();
      }
    }
    if (providers.hasAdMob) {
      try {
        final ok = await _admob.validateCredentials();
        if (ok) return (true, null);
        lastError = lastError ?? 'AdMob Publisher ID o credenciales OAuth inválidas.';
      } catch (e) {
        lastError = lastError ?? e.toString();
      }
    }
    return (false, lastError ?? 'Credenciales inválidas.');
  }

  /// Valida credenciales. Retorna true si ok, false si falla (sin distinguir motivo).
  Future<bool> validateCredentials() async {
    final (valid, _) = await validateCredentialsWithError();
    return valid;
  }
}
