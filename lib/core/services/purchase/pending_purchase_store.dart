import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:lantern/core/services/local_storage_service.dart';

/// Persists the plan id and affiliate code chosen for an in-flight purchase, so
/// background acknowledge retries and post-restart re-delivery can still
/// attribute the sale.
///
/// Each purchase is keyed by its store transaction id when present, falling
/// back to the product id. Plan and coupon are kept in two separate maps to
/// preserve the original on-disk format; the single remember/forget API writes
/// and clears both together so they can't drift apart.
class PendingPurchaseStore {
  PendingPurchaseStore(this._storage);

  /// Resolved lazily so construction doesn't require [LocalStorageService] to
  /// be registered yet, and tests can inject a fake.
  final LocalStorageService Function() _storage;

  static const _plansStorageKey = 'pending_purchase_plans_json';
  static const _couponsStorageKey = 'pending_purchase_coupons_json';
  static const _productKeyPrefix = 'product:';
  static const _transactionKeyPrefix = 'transaction:';

  // --- Public API --------------------------------------------------------

  /// Remembers the plan/coupon at purchase initiation, keyed by product id only
  /// (no transaction id exists yet).
  Future<void> rememberForProduct(
    String productID, {
    String planId = '',
    String couponCode = '',
  }) => _remember(
    [_productKey(productID)],
    planId: planId,
    couponCode: couponCode,
  );

  /// Remembers the plan/coupon for a delivered purchase, keyed by both its
  /// transaction id (when present) and product id.
  Future<void> rememberForPurchase(
    PurchaseDetails purchase, {
    String planId = '',
    String couponCode = '',
  }) => _remember(
    _keysFor(purchase),
    planId: planId,
    couponCode: couponCode,
  );

  Future<String?> planFor(PurchaseDetails purchase) =>
      _firstNonEmpty(_plansStorageKey, _keysFor(purchase));

  Future<String?> couponFor(PurchaseDetails purchase) =>
      _firstNonEmpty(_couponsStorageKey, _keysFor(purchase));

  Future<void> forgetPurchase(PurchaseDetails purchase) =>
      _forget(_keysFor(purchase));

  Future<void> forgetProduct(String productID) =>
      _forget([_productKey(productID)]);

  /// The most specific key for [purchase] (transaction id, else product id),
  /// used to dedupe in-flight acknowledgements and their retries.
  String retryKeyFor(PurchaseDetails purchase) => _keysFor(purchase).first;

  // --- Key derivation ----------------------------------------------------

  String _productKey(String productID) => '$_productKeyPrefix$productID';

  String? _transactionKey(PurchaseDetails purchase) {
    final purchaseID = purchase.purchaseID;
    if (purchaseID != null && purchaseID.isNotEmpty) {
      return '$_transactionKeyPrefix$purchaseID';
    }
    final transactionDate = purchase.transactionDate;
    if (transactionDate != null && transactionDate.isNotEmpty) {
      return '$_transactionKeyPrefix${purchase.productID}:$transactionDate';
    }
    return null;
  }

  /// Transaction key first (most specific) when present, then product key.
  List<String> _keysFor(PurchaseDetails purchase) {
    final keys = <String>[_productKey(purchase.productID)];
    final transactionKey = _transactionKey(purchase);
    if (transactionKey != null) {
      keys.insert(0, transactionKey);
    }
    return keys;
  }

  // --- Storage internals -------------------------------------------------

  Future<void> _remember(
    List<String> keys, {
    required String planId,
    required String couponCode,
  }) async {
    await _putAll(_plansStorageKey, keys, planId);
    await _putAll(_couponsStorageKey, keys, couponCode);
  }

  Future<void> _forget(List<String> keys) async {
    await _removeAll(_plansStorageKey, keys);
    await _removeAll(_couponsStorageKey, keys);
  }

  /// No-op when [value] is empty, so an absent plan/coupon never overwrites a
  /// previously stored one.
  Future<void> _putAll(
    String storageKey,
    List<String> keys,
    String value,
  ) async {
    if (value.isEmpty) return;
    final map = await _storage().getStringMap(storageKey);
    for (final key in keys) {
      map[key] = value;
    }
    await _storage().setStringMap(storageKey, map);
  }

  Future<void> _removeAll(String storageKey, List<String> keys) async {
    final map = await _storage().getStringMap(storageKey);
    var changed = false;
    for (final key in keys) {
      changed = map.remove(key) != null || changed;
    }
    if (changed) {
      await _storage().setStringMap(storageKey, map);
    }
  }

  Future<String?> _firstNonEmpty(String storageKey, List<String> keys) async {
    final map = await _storage().getStringMap(storageKey);
    for (final key in keys) {
      final value = map[key];
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }
    return null;
  }
}
