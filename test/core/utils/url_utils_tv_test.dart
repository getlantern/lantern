import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:i18n_extension/i18n_extension.dart' show Translations;
import 'package:i18n_extension_importer/i18n_extension_importer.dart';
import 'package:lantern/core/common/common.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Map<String, Map<String, String>> translations;

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
    addTearDown(() {
      Localization.translations = previousTranslations;
      Localization.defaultLocale = previousLocale;
      PlatformUtils.isTv = false;
    });
  });

  testWidgets('on TV an external link is shown as a QR code to scan', (
    tester,
  ) async {
    PlatformUtils.isTv = true;
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: mobileSize,
        child: MaterialApp(
          theme: AppTheme.appTheme(),
          home: const Scaffold(body: Text('host')),
        ),
      ),
    );
    final context = tester.element(find.text('host'));
    UrlUtils.tryLaunchExternalUrl(context, Uri.parse('https://lantern.io/x'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('tv.link.qr')), findsOneWidget);
    expect(find.text('https://lantern.io/x'), findsOneWidget);
    expect(find.text('Open on another device'), findsOneWidget);
    expect(
      find.byWidgetPredicate((w) => w is AlertDialog && w.scrollable),
      findsOneWidget,
      reason: 'long URLs must not push Close off screen',
    );
  });

  test('off TV showLinkOnTv declines so the link launches normally', () async {
    expect(await UrlUtils.showLinkOnTv(null, 'https://lantern.io'), isFalse);
  });
}
