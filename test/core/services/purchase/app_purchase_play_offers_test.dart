import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:lantern/core/services/app_purchase.dart';

PricingPhaseWrapper _phase(
  int micros, {
  String period = 'P1Y',
  int cycles = 0,
  RecurrenceMode mode = RecurrenceMode.infiniteRecurring,
}) => PricingPhaseWrapper(
  billingCycleCount: cycles,
  billingPeriod: period,
  formattedPrice: '\$${(micros / 1000000).toStringAsFixed(2)}',
  priceAmountMicros: micros,
  priceCurrencyCode: 'USD',
  recurrenceMode: mode,
);

/// A Play offer: a discounted first phase followed by the base price.
SubscriptionOfferDetailsWrapper _offer(
  String id,
  List<String> tags,
  int micros, {
  int base = 47990000,
  String period = 'P1Y',
  int cycles = 1,
}) => SubscriptionOfferDetailsWrapper(
  basePlanId: 'plan',
  offerId: id,
  offerTags: tags,
  offerIdToken: 'token-$id',
  pricingPhases: [
    _phase(
      micros,
      period: period,
      cycles: cycles,
      mode: RecurrenceMode.finiteRecurring,
    ),
    _phase(base, period: period),
  ],
);

SubscriptionOfferDetailsWrapper _basePlan(
  int micros, {
  String period = 'P1Y',
}) => SubscriptionOfferDetailsWrapper(
  basePlanId: 'plan',
  offerTags: const [],
  offerIdToken: 'token-base',
  pricingPhases: [_phase(micros, period: period)],
);

/// One [ProductDetails] per entry of [offers], in Play's order.
List<ProductDetails> _play(
  String id,
  List<SubscriptionOfferDetailsWrapper> offers,
) => GooglePlayProductDetails.fromProductDetails(
  ProductDetailsWrapper(
    description: '',
    name: id,
    productId: id,
    productType: ProductType.subs,
    subscriptionOfferDetails: offers,
    title: id,
  ),
);

class _Store extends Fake implements InAppPurchase {
  _Store(this.products);
  final List<ProductDetails> products;

  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> ids) async =>
      ProductDetailsResponse(productDetails: products, notFoundIDs: []);
}

void main() {
  AppPurchase build(List<ProductDetails> products) => AppPurchase(
    inAppPurchase: _Store(products),
    canUseBilling: () => true,
    isAndroid: true,
  );

  final retention = _offer('retention-30', ['retention'], 33590000);
  final untagged = _offer('us-test', [], 20000000);
  final affiliate = _offer('affiliate-15off', ['affiliate'], 40790000);
  final intro = _offer('intro-15', ['acquisition'], 40790000);
  final yearlyBase = _basePlan(47990000);

  test('prefers the acquisition offer over the base plan', () async {
    final purchases = build([
      ..._play('1y_sub', [retention, untagged, affiliate, intro, yearlyBase]),
      ..._play('1m_sub', [_basePlan(11990000, period: 'P1M')]),
    ]);

    await purchases.fetchSubscriptions();

    final year = purchases.storePriceFor('1y-usd-10')!;
    expect(year.amount, 40.79);
    expect(year.regular, '\$47.99');
    expect(year.offerMonths, 12);
    expect(year.monthly, closeTo(40.79 / 12, 0.001));
    final month = purchases.storePriceFor('1m-usd-10')!;
    expect(month.amount, 11.99);
    expect(month.regular, month.formatted);
    expect(month.offerMonths, isNull);
  });

  test('sells the base plan when Play returns no acquisition offer', () async {
    final purchases = build(
      _play('1y_sub', [retention, untagged, affiliate, yearlyBase]),
    );

    await purchases.fetchSubscriptions();

    final year = purchases.storePriceFor('1y-usd-10')!;
    expect(year.amount, 47.99);
    expect(year.offerMonths, isNull);
  });

  test('an affiliate code picks the affiliate-tagged offer only', () async {
    final purchases = build(
      _play('1y_sub', [retention, untagged, intro, affiliate, yearlyBase]),
    );

    await purchases.fetchSubscriptions(includeOffers: true);

    final year = purchases.storePriceFor('1y-usd-10')!;
    expect(year.formatted, '\$40.79');
    expect(year.regular, '\$47.99');
  });

  test('an affiliate fetch fails without an affiliate-tagged offer', () async {
    final purchases = build(
      _play('1y_sub', [retention, untagged, intro, yearlyBase]),
    );

    await expectLater(
      purchases.fetchSubscriptions(includeOffers: true),
      throwsStateError,
    );
  });

  test('a multi-cycle monthly offer reports its whole term', () async {
    final purchases = build(
      _play('1m_sub', [
        _offer(
          'intro-10',
          ['acquisition'],
          10790000,
          base: 11990000,
          period: 'P1M',
          cycles: 2,
        ),
        _basePlan(11990000, period: 'P1M'),
      ]),
    );

    await purchases.fetchSubscriptions();

    final month = purchases.storePriceFor('1m-usd-10')!;
    expect(month.monthly, 10.79);
    expect(month.offerMonths, 2);
  });
}
