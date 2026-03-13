import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';
import '../../core/storage/secure_credentials_storage.dart';

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

/// Credenciales: se guardan en SharedPreferences (siempre) y en almacenamiento
/// seguro (Keychain/Keystore) cuando está disponible. Lectura: primero secure,
/// si falla o está vacío se usa prefs. Así no se pierde nada y en iOS/Android
/// se usa el almacenamiento más seguro.
class CredentialsRepository {
  CredentialsRepository({
    SharedPreferences? prefs,
    SecureCredentialsStorage? secure,
  })  : _prefs = prefs,
        _secure = secure ?? SecureCredentialsStorage();

  SharedPreferences? _prefs;
  final SecureCredentialsStorage _secure;

  Future<SharedPreferences> get _store async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// Lee: primero secure; si no hay valor, prefs. No se borra nada de prefs.
  Future<String?> _get(String key) async {
    var v = await _secure.read(key);
    if (v != null && v.trim().isNotEmpty) return v.trim();
    final store = await _store;
    v = store.getString(key);
    return (v != null && v.trim().isNotEmpty) ? v.trim() : null;
  }

  /// Escribe: primero prefs (respaldo), luego secure. No se pierde nada si secure falla.
  Future<void> _set(String key, String value) async {
    final store = await _store;
    await store.setString(key, value.trim());
    await _secure.write(key, value.trim());
  }

  Future<void> _remove(String key) async {
    final store = await _store;
    await store.remove(key);
    await _secure.delete(key);
  }

  Future<IronSourceCredentials?> getCredentials() async {
    final secretKey = await _get(AppConstants.storageSecretKey);
    final refreshToken = await _get(AppConstants.storageRefreshToken);
    if (secretKey != null && refreshToken != null) {
      return IronSourceCredentials(secretKey: secretKey, refreshToken: refreshToken);
    }
    return null;
  }

  Future<void> saveCredentials(String secretKey, String refreshToken) async {
    await _set(AppConstants.storageSecretKey, secretKey.trim());
    await _set(AppConstants.storageRefreshToken, refreshToken.trim());
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

  Future<String?> getAppLovinReportKey() async => _get(AppConstants.storageAppLovinReportKey);

  Future<void> saveAppLovinReportKey(String reportKey) async =>
      _set(AppConstants.storageAppLovinReportKey, reportKey);

  Future<String?> getAdMobPublisherId() async => _get(AppConstants.storageAdMobPublisherId);

  Future<void> saveAdMobPublisherId(String publisherId) async =>
      _set(AppConstants.storageAdMobPublisherId, publisherId);

  Future<String?> getAdMobRefreshToken() async => _get(AppConstants.storageAdMobRefreshToken);

  Future<void> saveAdMobRefreshToken(String token) async =>
      _set(AppConstants.storageAdMobRefreshToken, token);

  Future<void> clearAdMobRefreshToken() async =>
      _remove(AppConstants.storageAdMobRefreshToken);

  Future<void> clearAllAdMob() async {
    await _remove(AppConstants.storageAdMobPublisherId);
    await _remove(AppConstants.storageAdMobRefreshToken);
    await _remove(AppConstants.storageAdMobClientId);
    await _remove(AppConstants.storageAdMobClientSecret);
  }

  Future<String?> getAdMobClientId() async => _get(AppConstants.storageAdMobClientId);

  Future<void> saveAdMobClientId(String clientId) async =>
      _set(AppConstants.storageAdMobClientId, clientId);

  Future<String?> getAdMobClientSecret() async => _get(AppConstants.storageAdMobClientSecret);

  Future<void> saveAdMobClientSecret(String? secret) async {
    if (secret == null || secret.trim().isEmpty) {
      await _remove(AppConstants.storageAdMobClientSecret);
    } else {
      await _set(AppConstants.storageAdMobClientSecret, secret);
    }
  }

  /// Borra todas las credenciales (para reset de onboarding).
  Future<void> clearAll() async {
    await saveCredentials('', '');
    await _remove(AppConstants.storageAppLovinReportKey);
    await clearAllAdMob();
  }
}
