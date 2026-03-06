import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Escritura/lectura opcional en Keychain (iOS) / Keystore (Android).
/// Si falla, no se pierde nada: el llamador usa prefs como respaldo.
class SecureCredentialsStorage {
  SecureCredentialsStorage({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(
                encryptedSharedPreferences: true,
              ),
            );

  final FlutterSecureStorage _storage;

  Future<String?> read(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (_) {
      return null;
    }
  }

  Future<void> write(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (_) {}
  }

  Future<void> delete(String key) async {
    try {
      await _storage.delete(key: key);
    } catch (_) {}
  }
}
