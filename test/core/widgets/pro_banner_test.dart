import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:i18n_extension/i18n_extension.dart' show Translations;
import 'package:i18n_extension_importer/i18n_extension_importer.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/router/router.dart';
import 'package:lantern/core/services/injection_container.dart';

class _RecordingRouter extends AppRouter {
  final pushedRoutes = <PageRouteInfo>[];

  @override
  Future<T?> push<T extends Object?>(
    PageRouteInfo route, {
    OnNavigationFailure? onFailure,
  }) async {
    pushedRoutes.add(route);
    return null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Map<String, Map<String, String>> translations;
  late _RecordingRouter router;

  setUpAll(() async {
    translations = await GettextImporter().fromAssetFile(
      'en',
      'assets/locales/en.po',
    );
  });

  setUp(() {
    final previousTranslations = Localization.translations;
    final previousLocale = Localization.defaultLocale;
    Localization.translations = Translations.byLocale('en') + translations;
    Localization.defaultLocale = 'en';
    sl.pushNewScope();
    router = _RecordingRouter();
    sl.registerSingleton<AppRouter>(router);
    addTearDown(() async {
      Localization.translations = previousTranslations;
      Localization.defaultLocale = previousLocale;
      await sl.popScope();
      router.dispose();
    });
  });

  final endDate = DateTime(2026, 9, 14);
  for (final sample in [
    (
      renewal: ProRenewalInfo(ProRenewalState.withinWeek, endDate, 3),
      title: 'Pro expires September 14th, 3 days left',
      detail: 'Renewing adds time to your current end date',
    ),
    (
      renewal: ProRenewalInfo(ProRenewalState.withinWeek, endDate, 1),
      title: 'Pro expires September 14th, 1 day left',
      detail: 'Renewing adds time to your current end date',
    ),
    (
      renewal: ProRenewalInfo(ProRenewalState.expiresToday, endDate, 0),
      title: 'Pro time ends today, September 14th',
      detail: 'Renew now to keep unlimited data and Pro features',
    ),
    (
      renewal: ProRenewalInfo(ProRenewalState.expired, endDate, -1),
      title: 'Your Pro time expired on September 14th',
      detail: 'Renew now to get back unlimited data',
    ),
    (
      renewal: const ProRenewalInfo(ProRenewalState.expired, null, 0),
      title: 'Your Pro subscription has expired',
      detail: 'Renew now to get back unlimited data',
    ),
  ]) {
    testWidgets('compact renewal shows ${sample.title}', (tester) async {
      final renewal = sample.renewal;
      final title = sample.title;
      final detail = sample.detail;
      await _pumpBanner(tester, renewal: renewal);

      expect(tester.getSize(find.byType(ProBanner)).height, 56);
      expect(
        find.text('Renew Pro - $title', findRichText: true),
        findsOneWidget,
      );
      final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
      expect(tooltip.message, '$title\n$detail');
      final material = tester.widget<Material>(
        find.descendant(
          of: find.byType(ProBanner),
          matching: find.byType(Material),
        ),
      );
      final context = tester.element(find.byType(ProBanner));
      expect(
        material.color,
        renewal.state == ProRenewalState.withinWeek
            ? context.bgPromo
            : context.statusErrorBg,
      );
      await tester.tap(find.byType(InkWell));
      expect(router.pushedRoutes, [isA<Plans>()]);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('regular screens retain the full renewal message and button', (
    tester,
  ) async {
    await _pumpBanner(
      tester,
      renewal: ProRenewalInfo(ProRenewalState.expiresToday, endDate, 0),
      size: const Size(390, 800),
    );
    expect(find.text('renew_now_keep_data'.i18n), findsOneWidget);
    expect(find.byType(ProButton), findsOneWidget);
    expect(tester.getSize(find.byType(ProBanner)).height, greaterThan(56));
    await tester.tap(find.text('renew_pro'.i18n));
    expect(router.pushedRoutes, [isA<Plans>()]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact upsell keeps its custom message and opens plans', (
    tester,
  ) async {
    await _pumpBanner(tester, title: 'Custom offer');
    expect(
      find.text('Upgrade to Pro - Custom offer', findRichText: true),
      findsOneWidget,
    );
    expect(tester.getSize(find.byType(ProBanner)).height, 56);
    await tester.tap(find.byType(InkWell));
    expect(router.pushedRoutes, [isA<Plans>()]);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpBanner(
  WidgetTester tester, {
  ProRenewalInfo renewal = ProRenewalInfo.none,
  Size size = const Size(320, 568),
  String? title,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        proRenewalProvider.overrideWithValue(renewal),
        isUserProProvider.overrideWithValue(
          renewal.state != ProRenewalState.none &&
              renewal.state != ProRenewalState.expired,
        ),
        isUserExpiredProvider.overrideWithValue(
          renewal.state == ProRenewalState.expired,
        ),
      ],
      child: ScreenUtilInit(
        designSize: mobileSize,
        child: MaterialApp(
          theme: AppTheme.appTheme(),
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ProBanner(title: title),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}
