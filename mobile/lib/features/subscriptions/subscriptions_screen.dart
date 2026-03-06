import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/iap/iap_service.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/locale_notifier.dart';
import '../../core/subscription/subscription_notifier.dart';
import '../../core/subscription/subscription_tier.dart';

class SubscriptionsScreen extends StatefulWidget {
  const SubscriptionsScreen({super.key});

  @override
  State<SubscriptionsScreen> createState() => _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends State<SubscriptionsScreen> {
  bool _loading = false;

  Future<void> _buyPro() async {
    if (_loading) return;
    if (!IapService.isAvailable || IapService.proProduct == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.t('iap_unavailable', LocaleNotifier.current))),
        );
      }
      return;
    }
    setState(() => _loading = true);
    try {
      final ok = await IapService.buyPro();
      if (!mounted) return;
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.t('purchase_ok', LocaleNotifier.current))),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.t('purchase_error', LocaleNotifier.current))),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _restore() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await IapService.restorePurchases();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.t('restore_ok', LocaleNotifier.current))),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = LocaleNotifier.current;
    final cs = Theme.of(context).colorScheme;
    final current = SubscriptionNotifier.current;
    final canBuy = IapService.isAvailable && IapService.proProduct != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.t('tab_subscriptions', locale)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              AppStrings.t('subscription_current', locale),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: cs.primary,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              color: cs.primaryContainer.withValues(alpha: 0.5),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: cs.primary, size: 28),
                    const SizedBox(width: 12),
                    Text(
                      current == SubscriptionTier.basic
                          ? AppStrings.t('tier_basic', locale)
                          : AppStrings.t('tier_pro', locale),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            _PlanCard(
              title: AppStrings.t('subscription_plan_basic', locale),
              shortDesc: AppStrings.t('subscription_plan_basic_short', locale),
              bulletKeys: const ['plan_bullet_home', 'plan_bullet_date_filters', 'plan_bullet_totals_by_day'],
              isCurrent: current == SubscriptionTier.basic,
              locale: locale,
            ),
            const SizedBox(height: 12),
            _PlanCard(
              title: AppStrings.t('subscription_plan_pro', locale),
              shortDesc: AppStrings.t('subscription_plan_pro_short', locale),
              bulletKeys: const [
                'plan_bullet_home',
                'plan_bullet_date_filters',
                'plan_bullet_filters',
                'plan_bullet_table',
                'plan_bullet_details',
                'plan_bullet_ai',
              ],
              isCurrent: current == SubscriptionTier.pro,
              locale: locale,
            ),
            if (canBuy && current != SubscriptionTier.pro) ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _loading ? null : _buyPro,
                icon: _loading ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: cs.onPrimary)) : const Icon(Icons.shopping_cart),
                label: Text(AppStrings.t('buy_pro', locale)),
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
              ),
            ],
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _loading ? null : _restore,
              icon: const Icon(Icons.restore),
              label: Text(AppStrings.t('restore_purchases', locale)),
            ),
            const SizedBox(height: 28),
            Text(
              AppStrings.t('how_to_buy', locale),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppStrings.t('how_to_buy_hint', locale),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.title,
    required this.shortDesc,
    required this.bulletKeys,
    required this.isCurrent,
    required this.locale,
  });

  final String title;
  final String shortDesc;
  final List<String> bulletKeys;
  final bool isCurrent;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: isCurrent ? 2 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isCurrent ? cs.primary : cs.outline.withValues(alpha: 0.3),
          width: isCurrent ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isCurrent ? cs.primary : cs.onSurface,
                  ),
                ),
                if (isCurrent) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.check_circle, size: 20, color: cs.primary),
                ],
              ],
            ),
            const SizedBox(height: 6),
            Text(
              shortDesc,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
            ...bulletKeys.map((key) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Icon(Icons.check, size: 16, color: isCurrent ? cs.primary : cs.onSurfaceVariant),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          AppStrings.t(key, locale),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: cs.onSurface,
                                height: 1.35,
                              ),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}
