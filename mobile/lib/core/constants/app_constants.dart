/// Application-wide constants.
class AppConstants {
  AppConstants._();

  static const String appName = 'Ad Revenue Dashboard - For ironSource';

  /// Bearer API: obtener token con Secret Key + Refresh Token (Mi cuenta → My Account)
  static const String ironsourceAuthUrl =
      'https://platform.ironsrc.com/partners/publisher/auth';
  /// LevelPlay Reporting API v1 (Bearer token, sin email)
  static const String ironsourceReportingV1Url =
      'https://platform.ironsrc.com/levelPlay/reporting/v1';
  /// v6 es la versión actual según documentación; si falla, la app puede reintentar con v3.
  static const String ironsourceApplicationsUrl =
      'https://platform.ironsrc.com/partners/publisher/applications/v6';

  /// Rate limit: 8,000 requests per hour (v1)
  static const int ironsourceRateLimitRequests = 8000;
  static const Duration ironsourceRateLimitWindow = Duration(hours: 1);

  /// Secure storage keys (solo en dispositivo)
  static const String storageSecretKey = 'ironsource_secret_key';
  static const String storageRefreshToken = 'ironsource_refresh_token';
  static const String storageThemeMode = 'app_theme_mode';
  static const String storageLocale = 'app_locale';
  static const String storageDashboardFilters = 'dashboard_filters';
  static const String storageMetricFiltersPrefix = 'metric_filters_';
}
