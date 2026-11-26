import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:i18n_extension/i18n_extension.dart' show Translations;
import 'package:i18n_extension_importer/i18n_extension_importer.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/extensions/plan.dart';
import 'package:lantern/core/models/plan_data.dart';

Android _method(String method, String name, {bool subscription = false}) =>
    Android(
      method: method,
      providers: Provider(
        name: name,
        icons: const [],
        supportSubscription: subscription,
      ),
    );

Plan _plan(String id) => Plan(
  id: id,
  description: id,
  usdPrice: 4800,
  price: const {'usd': 4800},
  expectedMonthlyPrice: const {'usd': 400},
);

void main() {
  setUp(() async {
    final previousTranslations = Localization.translations;
    final previousLocale = Localization.defaultLocale;
    final en = await GettextImporter().fromString(
      'en',
      File('assets/locales/en.po').readAsStringSync(),
    );
    Localization.translations = Translations.byLocale('en') + en;
    Localization.defaultLocale = 'en';
    addTearDown(() {
      Localization.translations = previousTranslations;
      Localization.defaultLocale = previousLocale;
    });
  });

  List<String> sortedNames(List<Android> desktop) {
    final data = PlansData(
      providers: Providers(android: [], desktop: desktop),
      plans: [],
    )..sortPlansAndProviders();
    return data.providers.desktop.map((m) => m.providers.name).toList();
  }

  test('keeps the server order when it puts a wallet first', () {
    expect(
      sortedNames([
        _method('wechatpay', 'shepherd-wechat'),
        _method('alipay', 'shepherd'),
        _method('credit-card', 'stripe', subscription: true),
      ]),
      ['shepherd-wechat', 'shepherd', 'stripe'],
    );
  });

  test('moves subscription methods first and keeps the rest in order', () {
    expect(
      sortedNames([
        _method('bank-transfer', 'other-a'),
        _method('credit-card', 'stripe', subscription: true),
        _method('crypto', 'other-b'),
        _method('alipay', 'shepherd'),
      ]),
      ['stripe', 'other-a', 'other-b', 'shepherd'],
    );
  });

  test('handles an empty provider list', () {
    expect(sortedNames([]), isEmpty);
  });

  test('payment methods use translated names', () {
    expect(_method('wechatpay', 'shepherd-wechat').label, 'WeChat Pay');
    expect(_method('alipay', 'shepherd').label, 'Alipay');
    expect(_method('credit-card', 'stripe').label, 'Credit Card');
    expect(_method('bank-transfer', 'other').label, 'Bank Transfer');
  });

  test('auto-renew notice matches the plan length', () {
    expect(
      _plan('1m-usd-10').autoRenewNotice,
      'Billed every month. Cancel anytime.',
    );
    expect(
      _plan('1y-usd-10').autoRenewNotice,
      'Billed every year. Cancel anytime.',
    );
    expect(
      _plan('2y-usd-10').autoRenewNotice,
      'Billed every two years. Cancel anytime.',
    );
    expect(
      _plan('lifetime').autoRenewNotice,
      'Renews automatically. Cancel anytime.',
    );
  });
}
