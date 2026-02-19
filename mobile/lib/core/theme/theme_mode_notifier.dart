import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';

/// Preferencia de tema persistida y notificador para que la app se actualice al cambiar.
class ThemeModeNotifier {
  ThemeModeNotifier._();

  static final ValueNotifier<ThemeMode> valueNotifier =
      ValueNotifier<ThemeMode>(ThemeMode.dark);

  static const String _key = AppConstants.storageThemeMode;
  static const String _light = 'light';
  static const String _dark = 'dark';

  static ThemeMode _fromString(String? v) {
    switch (v) {
      case _light:
        return ThemeMode.light;
      case _dark:
        return ThemeMode.dark;
      default:
        return ThemeMode.dark;
    }
  }

  static String _toString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return _light;
      case ThemeMode.dark:
        return _dark;
      case ThemeMode.system:
        return _dark;
    }
  }

  /// Carga el tema guardado y actualiza el notificador.
  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_key);
    valueNotifier.value = _fromString(stored);
  }

  /// Guarda y aplica el nuevo tema (actualiza el notificador).
  static Future<void> set(ThemeMode mode) async {
    valueNotifier.value = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, _toString(mode));
  }

  static ThemeMode get current => valueNotifier.value;
}
