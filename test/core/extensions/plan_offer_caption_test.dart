import 'package:flutter_test/flutter_test.dart';
import 'package:i18n_extension/i18n_extension.dart' show Translations;
import 'package:lantern/core/extensions/plan.dart';
import 'package:lantern/core/localization/i18n.dart';
import 'package:lantern/core/services/app_purchase.dart';

StorePrice _price(int? offerMonths, {String regular = '\$47.99'}) => (
  formatted: '\$40.79',
  amount: 40.79,
  currencyCode: 'USD',
  regular: regular,
  monthly: null,
  offerMonths: offerMonths,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final previousTranslations = Localization.translations;
    final previousLocale = Localization.defaultLocale;
    addTearDown(() {
      Localization.translations = previousTranslations;
      Localization.defaultLocale = previousLocale;
    });
    Localization.translations = Translations.byLocale('en-US');
    Localization.defaultLocale = 'en_US';
    await Localization.loadTranslations();
  });

  test('a one-year offer on the yearly plan', () {
    expect(
      storeOfferCaptionFor(_price(12), '1y-usd-10'),
      'First year, then \$47.99/year',
    );
  });

  test('one- and multi-month offers on the monthly plan', () {
    expect(
      storeOfferCaptionFor(_price(1, regular: '\$11.99'), '1m-usd-10'),
      'First month, then \$11.99/month',
    );
    expect(
      storeOfferCaptionFor(_price(2, regular: '\$11.99'), '1m-usd-10'),
      'First 2 months, then \$11.99/month',
    );
  });

  test('a multi-year offer', () {
    expect(
      storeOfferCaptionFor(_price(24), '1y-usd-10'),
      'First 2 years, then \$47.99/year',
    );
  });

  test('no caption without an offer term', () {
    expect(storeOfferCaptionFor(_price(null), '1y-usd-10'), '');
  });
}
