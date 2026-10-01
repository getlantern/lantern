import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:lantern/core/services/app_purchase.dart';

final _product = ProductDetails(
  id: '1m_sub',
  title: 'Monthly',
  description: '',
  price: r'$1.00',
  rawPrice: 1,
  currencyCode: 'USD',
);

class _Store extends Fake implements InAppPurchase {
  bool reachable = true;

  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> ids) async {
    if (!reachable) throw Exception('store unreachable');
    return ProductDetailsResponse(productDetails: [_product], notFoundIDs: []);
  }
}

void main() {
  late _Store store;

  AppPurchase build({bool allowed = true}) =>
      AppPurchase(inAppPurchase: store, canUseBilling: () => allowed);

  setUp(() => store = _Store());

  test('follows the billing policy', () {
    expect(build(allowed: false).isStoreBillingAvailable, isFalse);
    expect(build().isStoreBillingAvailable, isTrue);
  });

  test('products load marks the store reachable and notifies', () async {
    final purchases = build();
    var notifications = 0;
    purchases.productsLoaded.addListener(() => notifications++);

    await purchases.fetchSubscriptions();

    expect(purchases.productsLoaded.value, isTrue);
    expect(notifications, 1);
  });

  test('a failed fetch clears reachability after retries', () async {
    final purchases = build();
    await purchases.fetchSubscriptions();
    store.reachable = false;

    await expectLater(
      purchases.fetchSubscriptions(maxAttempts: 1),
      throwsStateError,
    );

    expect(purchases.productsLoaded.value, isFalse);
  });

  test('a refetch keeps the store reachable until it fails', () async {
    final purchases = build();
    await purchases.fetchSubscriptions();
    var sawFalse = false;
    purchases.productsLoaded.addListener(() {
      if (!purchases.productsLoaded.value) sawFalse = true;
    });

    await purchases.fetchSubscriptions(includeOffers: false);

    expect(sawFalse, isFalse);
    expect(purchases.productsLoaded.value, isTrue);
  });
}
