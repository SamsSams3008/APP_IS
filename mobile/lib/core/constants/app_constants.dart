/// Application-wide constants.
class AppConstants {
  AppConstants._();

  static const String appName = 'Ad Revenue Dashboard';

  /// AppLovin MAX Revenue Reporting API (Report Key)
  static const String appLovinReportUrl = 'https://r.applovin.com/maxReport';

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
  static const String storageAppLovinReportKey = 'applovin_report_key';
  static const String storageAdMobPublisherId = 'admob_publisher_id';
  static const String storageAdMobRefreshToken = 'admob_refresh_token';
  static const String storageAdMobClientId = 'admob_oauth_client_id';
  static const String storageAdMobClientSecret = 'admob_oauth_client_secret';

  /// OAuth redirect para AdMob. Registrar en Google Cloud Console (URIs de redirección).
  static const String admobOAuthRedirectUri = 'http://localhost:8765/oauth2callback';
  static const String storageThemeMode = 'app_theme_mode';
  static const String storageLocale = 'app_locale';
  static const String storageDashboardFilters = 'dashboard_filters';
  static const String storageMetricFiltersPrefix = 'metric_filters_';
}
