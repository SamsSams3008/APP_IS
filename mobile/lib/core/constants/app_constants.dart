/// Application-wide constants.
class AppConstants {
  AppConstants._();

  static const String appName = 'IronSource Dashboard';

  /// IronSource Reporting API (v5)
  static const String ironsourceStatsBaseUrl =
      'https://platform.ironsrc.com/partners/publisher/mediation/applications/v5/stats';
  static const String ironsourceApplicationsUrl =
      'https://platform.ironsrc.com/partners/publisher/applications/v3';

  /// Rate limit: 20 requests per 10 minutes
  static const int ironsourceRateLimitRequests = 20;
  static const Duration ironsourceRateLimitWindow = Duration(minutes: 10);

  /// Secure storage keys (copia local)
  static const String storageIronsourceEmail = 'ironsource_email';
  static const String storageIronsourceSecret = 'ironsource_secret';

  /// Firestore (credenciales para el cron del backend)
  static const String collectionUsers = 'users';
  static const String fieldIronsourceEmail = 'ironsourceEmail';
  static const String fieldIronsourceSecret = 'ironsourceSecret';
}
