import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:lantern/core/services/local_storage_service.dart';
import 'package:lantern/core/services/purchase/pending_purchase_store.dart';

/// In-memory [LocalStorageService] backing only the string-map API the store
/// uses. `_prefs` is `late` and never touched, so subclassing is safe.
class _FakeStorage extends LocalStorageService {
  final Map<String, Map<String, String>> maps = {};

  @override
  Future<Map<String, String>> getStringMap(String key) async =>
      Map<String, String>.from(maps[key] ?? const {});

  @override
  Future<void> setStringMap(String key, Map<String, String> value) async {
    if (value.isEmpty) {
      maps.remove(key);
      return;
    }
    maps[key] = Map<String, String>.from(value);
  }
}

PurchaseDetails _purchase({
  String productID = '1y_sub',
  String? purchaseID,
  String? transactionDate,
}) => PurchaseDetails(
  purchaseID: purchaseID,
  productID: productID,
  transactionDate: transactionDate,
  status: PurchaseStatus.purchased,
  verificationData: PurchaseVerificationData(
    localVerificationData: 'local',
    serverVerificationData: 'server',
    source: 'test',
  ),
);

void main() {
  late _FakeStorage storage;
  late PendingPurchaseStore store;

  setUp(() {
    storage = _FakeStorage();
    store = PendingPurchaseStore(() => storage);
  });

  group('rememberForPurchase / resolve', () {
    test('round-trips plan and coupon for a delivered purchase', () async {
      final purchase = _purchase(purchaseID: 'txn-1');
      await store.rememberForPurchase(
        purchase,
        planId: '1y-usd-10',
        couponCode: 'AFF20',
      );

      expect(await store.planFor(purchase), '1y-usd-10');
      expect(await store.couponFor(purchase), 'AFF20');
    });

    test('stores under both the transaction and product keys', () async {
      final purchase = _purchase(purchaseID: 'txn-1');
      await store.rememberForPurchase(purchase, planId: '1y-usd-10');

      expect(storage.maps['pending_purchase_plans_json'], {
        'transaction:txn-1': '1y-usd-10',
        'product:1y_sub': '1y-usd-10',
      });
    });

    test('resolves by product key when no transaction id was assigned',
        () async {
      // Remembered at initiation (product key only)...
      await store.rememberForProduct('1y_sub', planId: '1y-usd-10');
      // ...then delivered with a transaction id.
      final delivered = _purchase(purchaseID: 'txn-1');

      expect(await store.planFor(delivered), '1y-usd-10');
    });

    test('returns null when nothing was stored', () async {
      final purchase = _purchase(purchaseID: 'txn-1');
      expect(await store.planFor(purchase), isNull);
      expect(await store.couponFor(purchase), isNull);
    });
  });

  group('empty values never overwrite', () {
    test('an empty coupon leaves a previously stored plan intact', () async {
      final purchase = _purchase(purchaseID: 'txn-1');
      await store.rememberForPurchase(purchase, planId: '1y-usd-10');
      // Re-remember with no coupon (the common "plan only" case).
      await store.rememberForPurchase(purchase, couponCode: '');

      expect(await store.planFor(purchase), '1y-usd-10');
      expect(await store.couponFor(purchase), isNull);
      expect(storage.maps.containsKey('pending_purchase_coupons_json'), isFalse);
    });
  });

  group('forgetPurchase', () {
    test('clears both plan and coupon in lockstep', () async {
      final purchase = _purchase(purchaseID: 'txn-1');
      await store.rememberForPurchase(
        purchase,
        planId: '1y-usd-10',
        couponCode: 'AFF20',
      );

      await store.forgetPurchase(purchase);

      expect(await store.planFor(purchase), isNull);
      expect(await store.couponFor(purchase), isNull);
      expect(storage.maps, isEmpty);
    });

    test('leaves an unrelated purchase untouched', () async {
      final a = _purchase(productID: '1y_sub', purchaseID: 'txn-a');
      final b = _purchase(productID: '1m_sub', purchaseID: 'txn-b');
      await store.rememberForPurchase(a, planId: '1y-usd-10');
      await store.rememberForPurchase(b, planId: '1m-usd-10');

      await store.forgetPurchase(a);

      expect(await store.planFor(a), isNull);
      expect(await store.planFor(b), '1m-usd-10');
    });
  });

  group('retryKeyFor', () {
    test('prefers the transaction id', () {
      expect(
        store.retryKeyFor(_purchase(purchaseID: 'txn-1')),
        'transaction:txn-1',
      );
    });

    test('falls back to productID:date when there is no purchase id', () {
      expect(
        store.retryKeyFor(
          _purchase(productID: '1y_sub', transactionDate: '12345'),
        ),
        'transaction:1y_sub:12345',
      );
    });

    test('falls back to the product key when nothing identifies the txn', () {
      expect(
        store.retryKeyFor(_purchase(productID: '1y_sub')),
        'product:1y_sub',
      );
    });
  });
}
