import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';

import '../constants/app_constants.dart';
import '../subscription/subscription_notifier.dart';
import '../subscription/subscription_tier.dart';

/// Servicio de compras in-app. Una sola suscripción: Pro.
/// En iOS/Android usa Store/Play (vinculado a la cuenta Apple/Google).
/// Escuchar el stream antes del primer frame (véase [main]) para no perder restauraciones.
class IapService {
  IapService._();

  static final InAppPurchase _iap = InAppPurchase.instance;
  static StreamSubscription<List<PurchaseDetails>>? _subscription;
  static ProductDetails? _proProduct;
  static bool _initialized = false;
  static bool _storeAvailable = false;
  static Completer<void>? _restoreSyncCompleter;
  static Future<void> _restoreQueue = Future<void>.value();

  static ProductDetails? get proProduct => _proProduct;

  /// True si la tienda (iOS/Android) está disponible y el producto está cargado.
  static bool get isAvailable => _initialized && _storeAvailable;

  /// Inicializa el listener y sincroniza con la tienda (restore). Conviene llamarlo
  /// en [main] antes de [runApp] para no perder eventos tempranos del stream.
  static Future<void> init() async {
    if (!_initialized) {
      _storeAvailable = await _iap.isAvailable();
      if (_storeAvailable) {
        _subscription = _iap.purchaseStream.listen(
          _onPurchaseUpdates,
          onDone: () => _subscription = null,
          onError: (_) {},
        );
      }
      _initialized = true;
    }

    if (!_storeAvailable) return;

    await loadProducts();
    await _restorePurchasesAndWait();
  }

  /// Tras volver desde segundo plano, vuelve a pedir estado a Store/Play.
  static Future<void> refreshFromStore() async {
    if (!_initialized || !_storeAvailable) return;
    await loadProducts();
    await _restorePurchasesAndWait();
  }

  static Future<void> loadProducts() async {
    if (!_storeAvailable) return;
    try {
      final response = await _iap.queryProductDetails({AppConstants.iapProProductId});
      if (response.notFoundIDs.isNotEmpty) return;
      _proProduct = response.productDetails.isEmpty ? null : response.productDetails.first;
    } catch (_) {}
  }

  static void _finishRestoreWait() {
    final c = _restoreSyncCompleter;
    if (c != null && !c.isCompleted) c.complete();
  }

  static void _onPurchaseUpdates(List<PurchaseDetails> purchases) {
    for (final p in purchases) {
      if (p.productID != AppConstants.iapProProductId) continue;
      switch (p.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          SubscriptionNotifier.set(SubscriptionTier.pro);
          _iap.completePurchase(p);
          _finishRestoreWait();
          break;
        case PurchaseStatus.error:
        case PurchaseStatus.canceled:
          _finishRestoreWait();
          break;
        case PurchaseStatus.pending:
          break;
      }
    }
  }

  /// Compra la suscripción Pro. En desktop/web no hace nada.
  static Future<bool> buyPro() async {
    if (!_storeAvailable || _proProduct == null) return false;
    try {
      final param = PurchaseParam(productDetails: _proProduct!);
      return await _iap.buyNonConsumable(purchaseParam: param);
    } catch (_) {
      return false;
    }
  }

  /// Restaura compras enlazadas a la cuenta Apple/Google en el dispositivo.
  static Future<void> restorePurchases() async {
    if (!_storeAvailable) return;
    await _restorePurchasesAndWait();
  }

  static Future<void> _restorePurchasesAndWait() async {
    if (!_storeAvailable) return;

    final waiter = Completer<void>();
    _restoreQueue = _restoreQueue.catchError((_, _) {}).then((_) async {
      try {
        await _restorePurchasesAndWaitUnsafe();
      } finally {
        if (!waiter.isCompleted) waiter.complete();
      }
    });
    return waiter.future;
  }

  static Future<void> _restorePurchasesAndWaitUnsafe() async {
    final completer = Completer<void>();
    _restoreSyncCompleter = completer;

    try {
      await _iap.restorePurchases();
    } catch (_) {
      _finishRestoreWait();
    }

    await Future.any<void>([
      completer.future,
      Future.delayed(const Duration(seconds: 6)),
    ]);

    _restoreSyncCompleter = null;
  }

  static void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }
}
