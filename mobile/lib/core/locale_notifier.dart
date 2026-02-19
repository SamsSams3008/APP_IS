import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'constants/app_constants.dart';

/// Idioma de la app: 'es' o 'en'. Persistido en SharedPreferences.
class LocaleNotifier {
  LocaleNotifier._();

  static final ValueNotifier<String> valueNotifier = ValueNotifier<String>('es');

  static const String _key = AppConstants.storageLocale;

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_key);
    if (stored == 'en' || stored == 'es') valueNotifier.value = stored!;
  }

  static Future<void> set(String languageCode) async {
    if (languageCode != 'es' && languageCode != 'en') return;
    valueNotifier.value = languageCode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, languageCode);
  }

  static String get current => valueNotifier.value;
  static Locale get locale => Locale(current);
}
