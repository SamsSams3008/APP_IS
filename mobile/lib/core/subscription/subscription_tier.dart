/// Solo dos planes: Basic (gratis) y Pro (de pago).
enum SubscriptionTier {
  basic,
  pro,
}

extension SubscriptionTierExtension on SubscriptionTier {
  bool get hasFilters => this == SubscriptionTier.pro;
  bool get hasTable => this == SubscriptionTier.pro;
  bool get hasDetails => this == SubscriptionTier.pro;
  bool get hasAi => this == SubscriptionTier.pro;
}
