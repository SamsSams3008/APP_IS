/// Métricas que soporta cada proveedor de ads.
/// Solo se muestran métricas que TODOS los proveedores seleccionados soporten (AND).
///
/// Resumen por red:
/// - IronSource: todas (revenue, impressions, ecpm, clicks, completions, fill_rate,
///   completion_rate, revenue_per_completion, ctr, app_requests, dau, sessions).
/// - AdMob: revenue, impressions, ecpm, clicks, fill_rate, ctr, app_requests
///   (no tiene completions, completion_rate, revenue_per_completion, dau, sessions).
/// - AppLovin: solo base (revenue, impressions, ecpm).
class AvailableMetrics {
  AvailableMetrics._();

  /// Métricas base: las tres redes las tienen.
  static const List<String> baseMetricIds = [
    'revenue',
    'impressions',
    'ecpm',
  ];

  /// Métricas que solo IronSource tiene (no AdMob ni AppLovin).
  static const List<String> ironSourceOnlyMetricIds = [
    'clicks',
    'completions',
    'fill_rate',
    'completion_rate',
    'revenue_per_completion',
    'ctr',
    'app_requests',
    'dau',
    'sessions',
  ];

  /// Todas las métricas de IronSource (la red más completa).
  static const List<String> allIronSourceMetricIds = [
    ...baseMetricIds,
    ...ironSourceOnlyMetricIds,
  ];

  /// AppLovin solo expone base (revenue, impressions, ecpm).
  static const List<String> appLovinOnlyMetricIds = baseMetricIds;

  /// AdMob: base + clicks, fill_rate, ctr, app_requests (sin completions, completion_rate, revenue_per_completion, dau, sessions).
  static const List<String> admobMetricIds = [
    ...baseMetricIds,
    'clicks',
    'fill_rate',
    'ctr',
    'app_requests',
  ];

  /// Métricas por red (para la intersección).
  static List<String> metricsForNetwork(String networkId) {
    switch (networkId.toLowerCase()) {
      case 'ironsource':
        return allIronSourceMetricIds;
      case 'applovin':
        return appLovinOnlyMetricIds;
      case 'admob':
        return admobMetricIds;
      default:
        return List.from(baseMetricIds);
    }
  }

  /// Devuelve las métricas a mostrar según las redes seleccionadas (intersección).
  static List<String> forSelectedNetworks(Set<String> selectedNetworks) {
    if (selectedNetworks.isEmpty) return List.from(baseMetricIds);
    if (selectedNetworks.length == 1) {
      final list = metricsForNetwork(selectedNetworks.single);
      return list.toList()
        ..sort((a, b) =>
            allIronSourceMetricIds.indexOf(a).compareTo(allIronSourceMetricIds.indexOf(b)));
    }
    var result = allIronSourceMetricIds.toSet();
    for (final n in selectedNetworks) {
      result = result.intersection(metricsForNetwork(n).toSet());
    }
    return result
        .toList()
      ..sort((a, b) =>
          allIronSourceMetricIds.indexOf(a).compareTo(allIronSourceMetricIds.indexOf(b)));
  }

  /// Devuelve las métricas según los proveedores configurados (intersección).
  static List<String> forProviders({
    required bool hasIronSource,
    required bool hasAppLovin,
    required bool hasAdMob,
  }) {
    final networks = <String>{
      if (hasIronSource) 'ironsource',
      if (hasAppLovin) 'applovin',
      if (hasAdMob) 'admob',
    };
    return forSelectedNetworks(networks);
  }
}
