import 'package:badges/badges.dart' as badges;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:i18n_extension/i18n_extension.dart' show Translations;
import 'package:lantern/core/common/app_theme.dart';
import 'package:lantern/core/localization/i18n.dart';
import 'package:lantern/core/models/plan_data.dart';
import 'package:lantern/features/plans/plan_item.dart';

Plan _yearly({bool discounted = false}) => Plan(
  id: '1y-usd-10',
  description: 'one year plan',
  usdPrice: 4799,
  price: {'usd': 4799},
  expectedMonthlyPrice: {'usd': 400},
  bestValue: true,
  originalPrice: discounted ? {'usd': 5999} : null,
);

void main() {
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

  Future<void> pump(WidgetTester tester, Plan plan, {int discountPct = 0}) {
    // Wide enough for the test font, which is far wider than the real one.
    tester.view.physicalSize = const Size(800, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    return tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.appTheme(),
        home: Scaffold(
          body: PlanItem(
            plan: plan,
            planSelected: true,
            discountPct: discountPct,
            onPressed: (_) {},
          ),
        ),
      ),
    );
  }

  testWidgets('a plain card shows the monthly line and Best Value', (
    tester,
  ) async {
    await pump(tester, _yearly());

    expect(tester.takeException(), isNull);
    expect(find.text('Best Value!'), findsOneWidget);
    expect(find.textContaining('/month'), findsOneWidget);
    expect(find.text('Introductory Offer'), findsNothing);
  });

  testWidgets('an affiliate card keeps its strikethrough and no badge', (
    tester,
  ) async {
    await pump(tester, _yearly(discounted: true), discountPct: 15);

    expect(tester.takeException(), isNull);
    final original = tester.widget<Text>(find.textContaining('59.99'));
    expect(original.style!.decoration, TextDecoration.lineThrough);
    expect(find.textContaining('/month'), findsOneWidget);
    // The badges package keeps hidden content in the tree.
    final badge = tester.widget<badges.Badge>(find.byType(badges.Badge));
    expect(badge.showBadge, isFalse);
  });
}
