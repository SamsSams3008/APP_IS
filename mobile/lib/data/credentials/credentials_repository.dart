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
    return c != null;
  }
}
