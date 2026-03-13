import 'package:flutter/foundation.dart';

import 'subscription_tier.dart';

/// Suscripción actual. Solo Pro mediante pago real (IAP).
final class SubscriptionNotifier {
  SubscriptionNotifier._();

  static final ValueNotifier<SubscriptionTier> valueNotifier =
      ValueNotifier<SubscriptionTier>(SubscriptionTier.basic);

  static SubscriptionTier get current => valueNotifier.value;

  static Future<void> load() async {
    valueNotifier.value = SubscriptionTier.basic;
  }

  static Future<void> set(SubscriptionTier tier) async {
    if (valueNotifier.value == tier) return;
    valueNotifier.value = tier;
  }
}
