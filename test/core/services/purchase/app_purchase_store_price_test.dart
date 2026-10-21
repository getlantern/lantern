import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:in_app_purchase_storekit/store_kit_2_wrappers.dart';
import 'package:lantern/core/services/app_purchase.dart';

const _yearly = SK2SubscriptionPeriod(
  value: 1,
  unit: SK2SubscriptionPeriodUnit.year,
);

SK2SubscriptionOffer _offer(
  SK2SubscriptionOfferType type,
  double price, {
  SK2SubscriptionPeriod period = _yearly,
  int periodCount = 1,
  SK2SubscriptionOfferPaymentMode paymentMode =
      SK2SubscriptionOfferPaymentMode.payUpFront,
}) => SK2SubscriptionOffer(
  id: type == SK2SubscriptionOfferType.introductory ? null : 'promo',
  price: price,
  type: type,
  period: period,
  periodCount: periodCount,
  paymentMode: paymentMode,
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
  List<ProductDetails> products;

  /// When set, each query throws instead of answering.
  bool fail = false;

  /// When set, each query blocks until the caller completes its entry.
  final List<Completer<void>> gates = [];
  bool gated = false;

  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> ids) async {
    if (gated) {
      final gate = Completer<void>();
      gates.add(gate);
      await gate.future;
    }
    if (fail) throw Exception('store down');
    return ProductDetailsResponse(productDetails: products, notFoundIDs: []);
  }
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
    _Store? store,
  }) => AppPurchase(
    inAppPurchase: store ?? _Store(products),
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
    expect(price.monthly, closeTo(4999 / 12, 0.001));
    expect(purchases.storePriceFor('1m-inr-1'), isNull);
  });

  group('monthly figure', () {
    test('spreads a yearly pay-up-front intro offer over 12 months', () async {
      final purchases = build([base, affiliate]);

      await purchases.fetchSubscriptions(includeOffers: true);

      expect(
        purchases.storePriceFor('1y-inr-9')!.monthly,
        closeTo(3999 / 12, 0.001),
      );
    });

    test('is the charge itself for a one-month pay-up-front offer', () async {
      final oneMonth = _sk2Product(
        '1y_sub_affiliate',
        offers: [
          _offer(
            SK2SubscriptionOfferType.introductory,
            299,
            period: const SK2SubscriptionPeriod(
              value: 1,
              unit: SK2SubscriptionPeriodUnit.month,
            ),
          ),
        ],
      );
      final purchases = build([base, oneMonth]);

      await purchases.fetchSubscriptions(includeOffers: true);

      final price = purchases.storePriceFor('1y-inr-9')!;
      expect(price.amount, 299.0);
      expect(price.monthly, 299.0);
    });

    test('is per period for a pay-as-you-go offer', () async {
      final payAsYouGo = _sk2Product(
        '1y_sub_affiliate',
        offers: [
          _offer(
            SK2SubscriptionOfferType.introductory,
            600,
            period: const SK2SubscriptionPeriod(
              value: 3,
              unit: SK2SubscriptionPeriodUnit.month,
            ),
            periodCount: 2,
            paymentMode: SK2SubscriptionOfferPaymentMode.payAsYouGo,
          ),
        ],
      );
      final purchases = build([base, payAsYouGo]);

      await purchases.fetchSubscriptions(includeOffers: true);

      expect(purchases.storePriceFor('1y-inr-9')!.monthly, 200.0);
    });

    test('is omitted for a weekly offer', () async {
      final weekly = _sk2Product(
        '1y_sub_affiliate',
        offers: [
          _offer(
            SK2SubscriptionOfferType.introductory,
            99,
            period: const SK2SubscriptionPeriod(
              value: 1,
              unit: SK2SubscriptionPeriodUnit.week,
            ),
          ),
        ],
      );
      final purchases = build([base, weekly]);

      await purchases.fetchSubscriptions(includeOffers: true);

      expect(purchases.storePriceFor('1y-inr-9')!.monthly, isNull);
    });
  });

  test('prices the first SKU of a plan family, as purchased', () async {
    final cheaper = _sk2Product(
      '1y_sub_affiliate',
      offers: [_offer(SK2SubscriptionOfferType.introductory, 1999)],
    );
    final purchases = build([base, affiliate, cheaper]);

    await purchases.fetchSubscriptions(includeOffers: true);

    expect(purchases.storePriceFor('1y-inr-9')!.amount, 3999.0);
  });

  test('an opposite-mode request waits for the in-flight fetch', () async {
    final store = _Store([base, affiliate])..gated = true;
    final purchases = build([], store: store);

    final baseFetch = purchases.fetchSubscriptions();
    final offerFetch = purchases.fetchSubscriptions(includeOffers: true);
    await Future<void>.delayed(Duration.zero);
    expect(store.gates, hasLength(1));

    store.gates[0].complete();
    await baseFetch;
    expect(purchases.storePriceFor('1y-inr-9')!.amount, 4999.0);
    await Future<void>.delayed(Duration.zero);
    expect(store.gates, hasLength(2));

    store.gates[1].complete();
    await offerFetch;
    expect(purchases.storePriceFor('1y-inr-9')!.amount, 3999.0);
  });

  test('a same-mode request piggy-backs on the in-flight fetch', () async {
    final store = _Store([base, affiliate])..gated = true;
    final purchases = build([], store: store);

    final first = purchases.fetchSubscriptions(includeOffers: true);
    final second = purchases.fetchSubscriptions(includeOffers: true);
    await Future<void>.delayed(Duration.zero);

    store.gates.single.complete();
    await Future.wait([first, second]);
    expect(store.gates, hasLength(1));
  });

  test('a failed reload drops the previous prices', () async {
    final store = _Store([base, affiliate]);
    final purchases = build([], store: store);
    await purchases.fetchSubscriptions(includeOffers: true);
    final version = purchases.storePricesVersion.value;

    store.fail = true;
    await expectLater(
      purchases.fetchSubscriptions(maxAttempts: 1),
      throwsStateError,
    );

    expect(purchases.productsLoaded.value, isFalse);
    expect(purchases.storePriceFor('1y-inr-9'), isNull);
    expect(purchases.storePricesVersion.value, version + 1);
  });
}
