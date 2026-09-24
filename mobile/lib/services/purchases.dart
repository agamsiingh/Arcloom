// One-time "Arcloom Supporter" (ad-free) non-consumable purchase via the official
// in_app_purchase plugin (Google Play Billing / StoreKit).
//
// NOTE: entitlement is granted from the store's purchase stream on-device.
// There is no server-side receipt validation in this build.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'storage.dart';

const String adFreeProductId = 'arcloom_supporter';
const String adFreeFallbackPrice = r'$2.99';
const int supporterBonusHints = 10;

class PurchaseService extends ChangeNotifier {
  PurchaseService(this.store, {InAppPurchase? iap}) : _iap = iap; // ignore: prefer_initializing_formals

  final Store store;
  final InAppPurchase? _iap;
  StreamSubscription<List<PurchaseDetails>>? _sub;
  ProductDetails? product;
  bool storeAvailable = false;
  bool pending = false;
  String? lastError;
  void Function()? onEntitlementGranted;

  InAppPurchase get _plugin => _iap ?? InAppPurchase.instance;

  String get price => product?.price ?? adFreeFallbackPrice;

  Future<void> init() async {
    try {
      _sub = _plugin.purchaseStream.listen(_onPurchases, onError: (Object e) {
        lastError = '$e';
        pending = false;
        notifyListeners();
      });
      storeAvailable = await _plugin.isAvailable();
      if (storeAvailable) {
        final r = await _plugin.queryProductDetails({adFreeProductId});
        if (r.productDetails.isNotEmpty) product = r.productDetails.first;
        if (r.notFoundIDs.isNotEmpty) debugPrint('IAP product not found: ${r.notFoundIDs}');
      }
    } catch (e) {
      debugPrint('IAP init failed: $e');
      storeAvailable = false;
    }
    notifyListeners();
  }

  /// Starts the purchase flow. Returns false if it could not be started.
  Future<bool> buyAdFree() async {
    lastError = null;
    if (store.data.adFree) return true;
    if (!storeAvailable || product == null) {
      lastError = 'The store is unavailable right now. Please try again later.';
      notifyListeners();
      return false;
    }
    pending = true;
    notifyListeners();
    try {
      return await _plugin.buyNonConsumable(purchaseParam: PurchaseParam(productDetails: product!));
    } catch (e) {
      pending = false;
      lastError = 'Purchase could not be started.';
      notifyListeners();
      return false;
    }
  }

  Future<void> restore() async {
    lastError = null;
    if (!storeAvailable) {
      lastError = 'The store is unavailable right now.';
      notifyListeners();
      return;
    }
    try {
      await _plugin.restorePurchases();
    } catch (e) {
      lastError = 'Restore failed.';
      notifyListeners();
    }
  }

  Future<void> _onPurchases(List<PurchaseDetails> list) async {
    for (final p in list) {
      if (p.productID != adFreeProductId) continue;
      switch (p.status) {
        case PurchaseStatus.pending:
          pending = true;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await grantAdFree();
          pending = false;
        case PurchaseStatus.error:
          pending = false;
          lastError = p.error?.message ?? 'Purchase failed.';
        case PurchaseStatus.canceled:
          pending = false;
      }
      if (p.pendingCompletePurchase) {
        try {
          await _plugin.completePurchase(p);
        } catch (e) {
          debugPrint('completePurchase failed: $e');
        }
      }
    }
    notifyListeners();
  }

  Future<void> grantAdFree() async {
    final d = store.data;
    if (!d.adFree) d.hints += supporterBonusHints;
    d.adFree = true;
    await store.save();
    onEntitlementGranted?.call();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
