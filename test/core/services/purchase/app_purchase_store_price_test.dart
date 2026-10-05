import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:in_app_purchase_storekit/store_kit_2_wrappers.dart';
import 'package:lantern/core/services/app_purchase.dart';

final _yearly = SK2SubscriptionPeriod(
  value: 1,
  unit: SK2SubscriptionPeriodUnit.year,
);

SK2SubscriptionOffer _offer(SK2SubscriptionOfferType type, double price) =>
    SK2SubscriptionOffer(
      id: type == SK2SubscriptionOfferType.introductory ? null : 'promo',
      price: price,
      type: type,
      period: _yearly,
      periodCount: 1,
      paymentMode: SK2SubscriptionOfferPaymentMode.payUpFront,
    );

/// A StoreKit 2 product priced in INR, with [offers] on its subscription.
ProductDetails _sk2Product(
  String id, {
  List<SK2SubscriptionOffer> offers = const [],
}) => AppStoreProduct2Details.fromSK2Product(
  SK2Product(
    id: id,
    displayName: id,
    displayPrice: '₹4,999.00',
    description: '',
    price: 4999,
    type: SK2ProductType.autoRenewable,
    priceLocale: SK2PriceLocale(currencyCode: 'INR', currencySymbol: '₹'),
    subscription: SK2SubscriptionInfo(
      subscriptionGroupID: 'group',
      promotionalOffers: offers,
      subscriptionPeriod: _yearly,
    ),
  ),
);

class _Store extends Fake implements InAppPurchase {
  _Store(this.products);
  final List<ProductDetails> products;

  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> ids) async =>
      ProductDetailsResponse(productDetails: products, notFoundIDs: []);
}

// These run on the host, which AppPurchase treats as the non-Android (iOS)
// branch, so the affiliate SKU split applies.
void main() {
  final affiliate = _sk2Product(
    '1y_sub_affiliate',
    offers: [
      _offer(SK2SubscriptionOfferType.promotional, 2999),
      _offer(SK2SubscriptionOfferType.introductory, 3999),
    ],
  );
  final base = _sk2Product('1y_sub');

  AppPurchase build(
    List<ProductDetails> products, {
    Future<bool> Function(String id)? eligibility,
  }) => AppPurchase(
    inAppPurchase: _Store(products),
    canUseBilling: () => true,
    introOfferEligibility: eligibility ?? (_) async => true,
  );

  test('quotes the introductory offer of an affiliate SKU', () async {
    final purchases = build([base, affiliate]);

    await purchases.fetchSubscriptions(includeOffers: true);

    final price = purchases.storePriceFor('1y-inr-9')!;
    expect(price.amount, 3999.0);
    expect(price.currencyCode, 'INR');
    expect(price.formatted, contains('3,999'));
    expect(price.regular, '₹4,999.00');
  });

  test('quotes the regular price when the user is ineligible', () async {
    final checked = <String>[];
    final purchases = build(
      [base, affiliate],
      eligibility: (id) async {
        checked.add(id);
        return false;
      },
    );

    await purchases.fetchSubscriptions(includeOffers: true);

    expect(checked, ['1y_sub_affiliate']);
    final price = purchases.storePriceFor('1y-inr-9')!;
    expect(price.formatted, '₹4,999.00');
    expect(price.regular, price.formatted);
  });

  test('treats a failed eligibility lookup as eligible', () async {
    final purchases = build([
      base,
      affiliate,
    ], eligibility: (_) async => throw Exception('storekit down'));

    await purchases.fetchSubscriptions(includeOffers: true);

    expect(purchases.productsLoaded.value, isTrue);
    expect(purchases.storePriceFor('1y-inr-9')!.amount, 3999.0);
  });

  test('a base-plan fetch quotes the regular price without checking', () async {
    final checked = <String>[];
    final purchases = build(
      [base, affiliate],
      eligibility: (id) async {
        checked.add(id);
        return true;
      },
    );

    await purchases.fetchSubscriptions();

    expect(checked, isEmpty);
    final price = purchases.storePriceFor('1y-inr-9')!;
    expect(price.formatted, '₹4,999.00');
    expect(price.regular, price.formatted);
    expect(purchases.storePriceFor('1m-inr-1'), isNull);
  });
}
