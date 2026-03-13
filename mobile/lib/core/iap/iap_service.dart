import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';

import '../constants/app_constants.dart';
import '../subscription/subscription_notifier.dart';
import '../subscription/subscription_tier.dart';

/// Servicio de compras in-app. Una sola suscripción: Pro.
/// En iOS/Android usa Store/Play; en otras plataformas no hace compras reales.
class IapService {
  IapService._();

  static final InAppPurchase _iap = InAppPurchase.instance;
  static StreamSubscription<List<PurchaseDetails>>? _subscription;
  static ProductDetails? _proProduct;
  static bool _initialized = false;
  static bool _storeAvailable = false;

  static ProductDetails? get proProduct => _proProduct;
  /// True si la tienda (iOS/Android) está disponible y el producto está cargado.
  static bool get isAvailable => _initialized && _storeAvailable;

  /// Inicializa y escucha compras. Llamar al arranque de la app (p. ej. en splash).
  static Future<void> init() async {
    if (_subscription != null) return;
    _storeAvailable = await _iap.isAvailable();
    if (!_storeAvailable) {
      _initialized = true;
      return;
    }
    _subscription = _iap.purchaseStream.listen(
      _onPurchaseUpdates,
      onDone: () => _subscription = null,
      onError: (_) {},
    );
    await loadProducts();
    await restorePurchases();
    _initialized = true;
  }

  static Future<void> loadProducts() async {
    if (!_storeAvailable) return;
    try {
      final response = await _iap.queryProductDetails({AppConstants.iapProProductId});
      if (response.notFoundIDs.isNotEmpty) return;
      _proProduct = response.productDetails.isEmpty ? null : response.productDetails.first;
    } catch (_) {}
  }

  static void _onPurchaseUpdates(List<PurchaseDetails> purchases) {
    for (final p in purchases) {
      if (p.productID != AppConstants.iapProProductId) continue;
      switch (p.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          SubscriptionNotifier.set(SubscriptionTier.pro);
          _iap.completePurchase(p);
          break;
        case PurchaseStatus.error:
          // El UI puede mostrar el error si se pasa un callback
          break;
        case PurchaseStatus.pending:
        case PurchaseStatus.canceled:
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

  /// Restaura compras (p. ej. cambio de dispositivo). Actualiza el tier si hay Pro activa.
  static Future<void> restorePurchases() async {
    if (!_storeAvailable) return;
    try {
      await _iap.restorePurchases();
      // El stream enviará PurchaseDetails con status restored y _onPurchaseUpdates pondrá Pro
    } catch (_) {}
  }

  static void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }
}
