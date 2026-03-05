import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';

/// Credenciales para Bearer API (Secret Key + Refresh Token).
/// Se obtienen en IronSource → Mi cuenta → My Account.
class IronSourceCredentials {
  const IronSourceCredentials({
    required this.secretKey,
    required this.refreshToken,
  });

  final String secretKey;
  final String refreshToken;
}

/// Guarda y lee Secret Key y Refresh Token con SharedPreferences.
/// Evita el error de Keychain en iOS (-34018) y funciona en todos los dispositivos.
class CredentialsRepository {
  CredentialsRepository({SharedPreferences? prefs}) : _prefs = prefs;

  SharedPreferences? _prefs;

  Future<SharedPreferences> get _store async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  Future<IronSourceCredentials?> getCredentials() async {
    final store = await _store;
    final secretKey = store.getString(AppConstants.storageSecretKey);
    final refreshToken = store.getString(AppConstants.storageRefreshToken);
    if (secretKey != null && refreshToken != null &&
        secretKey.isNotEmpty && refreshToken.isNotEmpty) {
      return IronSourceCredentials(secretKey: secretKey, refreshToken: refreshToken);
    }
    return null;
  }

  Future<void> saveCredentials(String secretKey, String refreshToken) async {
    final sk = secretKey.trim();
    final rt = refreshToken.trim();
    final store = await _store;
    await store.setString(AppConstants.storageSecretKey, sk);
    await store.setString(AppConstants.storageRefreshToken, rt);
  }

  Future<bool> hasCredentials() async {
    final c = await getCredentials();
    final applovin = await getAppLovinReportKey();
    final admobOk = await hasAdMobCredentials();
    return (c != null) || (applovin != null) || admobOk;
  }

  Future<bool> hasAdMobCredentials() async {
    final pubId = await getAdMobPublisherId();
    final refresh = await getAdMobRefreshToken();
    return (pubId != null && pubId.isNotEmpty) && (refresh != null && refresh.isNotEmpty);
  }

  /// AppLovin MAX Report Key (Account > Keys in dash.applovin.com)
  Future<String?> getAppLovinReportKey() async {
    final store = await _store;
    return store.getString(AppConstants.storageAppLovinReportKey);
  }

  Future<void> saveAppLovinReportKey(String reportKey) async {
    final store = await _store;
    await store.setString(
      AppConstants.storageAppLovinReportKey,
      reportKey.trim(),
    );
  }

  /// AdMob Publisher ID (ca-app-pub-xxxxxxxx~yyyyyyyyy)
  Future<String?> getAdMobPublisherId() async {
    final store = await _store;
    final v = store.getString(AppConstants.storageAdMobPublisherId);
    return (v != null && v.trim().isNotEmpty) ? v.trim() : null;
  }

  Future<void> saveAdMobPublisherId(String publisherId) async {
    final store = await _store;
    await store.setString(
      AppConstants.storageAdMobPublisherId,
      publisherId.trim(),
    );
  }

  Future<String?> getAdMobRefreshToken() async {
    final store = await _store;
    final v = store.getString(AppConstants.storageAdMobRefreshToken);
    return (v != null && v.trim().isNotEmpty) ? v.trim() : null;
  }

  Future<void> saveAdMobRefreshToken(String token) async {
    final store = await _store;
    await store.setString(AppConstants.storageAdMobRefreshToken, token.trim());
  }

  Future<void> clearAdMobRefreshToken() async {
    final store = await _store;
    await store.remove(AppConstants.storageAdMobRefreshToken);
  }

  /// Borra todas las credenciales AdMob (desconectar).
  Future<void> clearAllAdMob() async {
    final store = await _store;
    await store.remove(AppConstants.storageAdMobPublisherId);
    await store.remove(AppConstants.storageAdMobRefreshToken);
    await store.remove(AppConstants.storageAdMobClientId);
    await store.remove(AppConstants.storageAdMobClientSecret);
  }

  Future<String?> getAdMobClientId() async {
    final store = await _store;
    final v = store.getString(AppConstants.storageAdMobClientId);
    return (v != null && v.trim().isNotEmpty) ? v.trim() : null;
  }

  Future<void> saveAdMobClientId(String clientId) async {
    final store = await _store;
    await store.setString(AppConstants.storageAdMobClientId, clientId.trim());
  }

  Future<String?> getAdMobClientSecret() async {
    final store = await _store;
    final v = store.getString(AppConstants.storageAdMobClientSecret);
    return (v != null && v.trim().isNotEmpty) ? v.trim() : null;
  }

  Future<void> saveAdMobClientSecret(String? secret) async {
    final store = await _store;
    if (secret == null || secret.trim().isEmpty) {
      await store.remove(AppConstants.storageAdMobClientSecret);
    } else {
      await store.setString(AppConstants.storageAdMobClientSecret, secret.trim());
    }
  }
}
