import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';
import 'subscription_tier.dart';

/// Suscripción actual. Solo Pro mediante pago real (IAP).
/// El tier Pro se guarda localmente tras confirmación de Store/Play; al abrir la
/// app se lee ese valor de inmediato y luego IAP sincroniza con la cuenta Apple/Google.
final class SubscriptionNotifier {
  SubscriptionNotifier._();

  static final ValueNotifier<SubscriptionTier> valueNotifier =
      ValueNotifier<SubscriptionTier>(SubscriptionTier.basic);

  static SubscriptionTier get current => valueNotifier.value;

  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final name = prefs.getString(AppConstants.storageSubscriptionTier);
      valueNotifier.value =
          name == SubscriptionTier.pro.name ? SubscriptionTier.pro : SubscriptionTier.basic;
    } catch (_) {
      valueNotifier.value = SubscriptionTier.basic;
    }
  }

  static Future<void> set(SubscriptionTier tier) async {
    if (valueNotifier.value != tier) {
      valueNotifier.value = tier;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.storageSubscriptionTier, tier.name);
    } catch (_) {}
  }

  /// Quitar Pro del almacén local cuando la tienda indica que no hay derecho vigente.
}
