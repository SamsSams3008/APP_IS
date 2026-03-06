import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';
import 'subscription_tier.dart';

/// Suscripción actual (simulada). Escuchar para reaccionar en la UI.
final class SubscriptionNotifier {
  SubscriptionNotifier._();

  static final ValueNotifier<SubscriptionTier> valueNotifier =
      ValueNotifier<SubscriptionTier>(SubscriptionTier.basic);

  static SubscriptionTier get current => valueNotifier.value;

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(AppConstants.storageSubscriptionTier);
    valueNotifier.value = _fromString(raw);
  }

  static Future<void> set(SubscriptionTier tier) async {
    if (valueNotifier.value == tier) return;
    valueNotifier.value = tier;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.storageSubscriptionTier, _toString(tier));
  }

  static SubscriptionTier _fromString(String? v) {
    switch (v?.toLowerCase()) {
      case 'pro':
        return SubscriptionTier.pro;
      default:
        return SubscriptionTier.basic;
    }
  }

  static String _toString(SubscriptionTier t) {
    switch (t) {
      case SubscriptionTier.basic:
        return 'basic';
      case SubscriptionTier.pro:
        return 'pro';
    }
  }
}
