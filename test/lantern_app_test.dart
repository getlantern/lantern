// WindowWrapper writes real URL handlers to the Windows registry. Keep these
// tests off Windows until that operation can be replaced in widget tests.
@TestOn('!windows')
library;

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:i18n_extension/i18n_extension.dart' show Translations;
import 'package:i18n_extension_importer/i18n_extension_importer.dart';
import 'package:lantern/core/common/app_eum.dart';
import 'package:lantern/core/localization/i18n.dart';
import 'package:lantern/core/models/app_setting.dart';
import 'package:lantern/core/router/router.dart';
import 'package:lantern/core/router/router.gr.dart';
import 'package:lantern/core/services/injection_container.dart';
import 'package:lantern/features/home/provider/app_setting_notifier.dart';
import 'package:lantern/features/system_tray/provider/system_tray_notifier.dart';
import 'package:lantern/features/vpn/provider/vpn_notifier.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';
import 'package:lantern/lantern_app.dart';

import 'features/user_message/user_message_test_fakes.dart';

const _invalidLinkMessage = 'This link is invalid. Please request a new one.';
const _affiliateLink = 'https://lantern.io/affiliate/HALF/extra';
const _appLinksChannel = MethodChannel('com.llfbandit.app_links/events');
const _windowChannel = MethodChannel('window_manager');

class _InitialRouteGuard extends AutoRouteGuard {
  bool hold = false;
  NavigationResolver? pending;

  @override
  void onNavigation(NavigationResolver resolver, StackRouter router) {
    if (hold) {
      pending = resolver;
    } else {
      resolver.next();
    }
  }

  void release() {
    hold = false;
    final resolver = pending;
    pending = null;
    resolver?.next();
  }
}

class _TestRouter extends AppRouter {
  _TestRouter(_InitialRouteGuard guard)
    : _routes = [
        NamedRouteDef(
          name: Home.name,
          path: '/',
          guards: [guard],
          builder: (_, _) => const Scaffold(body: Text('Test home')),
        ),
        NamedRouteDef(
          name: Plans.name,
          path: '/plans',
          builder: (_, data) => Scaffold(
            body: Text('Plans: ${data.argsAs<PlansArgs>().referralCode}'),
          ),
        ),
      ];

  final List<AutoRoute> _routes;

  @override
  List<AutoRoute> get routes => _routes;

  @override
  RouteType get defaultRouteType => const RouteType.material();
}

class _NoSystemTray extends SystemTrayNotifier {
  @override
  Future<void> build() async {}
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  final guard = _InitialRouteGuard();
  final router = _TestRouter(guard);
  late FakeUserMessageService service;
  var listening = false;

  setUpAll(() async {
    final previousTranslations = Localization.translations;
    final previousLocale = Localization.defaultLocale;
    final previousFontFetching = GoogleFonts.config.allowRuntimeFetching;
    addTearDown(() {
      Localization.translations = previousTranslations;
      Localization.defaultLocale = previousLocale;
      GoogleFonts.config.allowRuntimeFetching = previousFontFetching;
    });
    GoogleFonts.config.allowRuntimeFetching = false;
    Localization.translations =
        Translations.byLocale('en-US') +
        await GettextImporter().fromAssetFile('en-US', 'assets/locales/en.po');
    Localization.defaultLocale = 'en_US';

    // LanternApp keeps one global router, so each case resets its stack.
    await sl.reset();
    sl.registerSingleton<AppRouter>(router);
  });

  tearDownAll(() async {
    router.delegate().dispose();
    router.routeInfoProvider().dispose();
    await sl.reset();
  });

  setUp(() {
    guard.release();
    router.removeWhere((_) => true);
    service = FakeUserMessageService();
    listening = false;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(_appLinksChannel, (
      call,
    ) async {
      if (call.method == 'listen') listening = true;
      if (call.method == 'cancel') listening = false;
      return null;
    });
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      _windowChannel,
      (call) async => call.method.startsWith('is') ? false : null,
    );
    addTearDown(() async {
      await service.dispose();
      binding.defaultBinaryMessenger.setMockMethodCallHandler(
        _appLinksChannel,
        null,
      );
      binding.defaultBinaryMessenger.setMockMethodCallHandler(
        _windowChannel,
        null,
      );
    });
  });

  Future<void> mountApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appSettingProvider.overrideWithValue(
            const AppSetting(locale: 'en_US', themeMode: 'light'),
          ),
          vpnProvider.overrideWithValue(VPNStatus.disconnected),
          lanternServiceProvider.overrideWithValue(service),
          systemTrayProvider.overrideWith(_NoSystemTray.new),
        ],
        child: const LanternApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(listening, isTrue);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      guard.release();
      await tester.pump();
    });
  }

  void emitLink(String link) {
    expect(listening, isTrue);
    binding.channelBuffers.push(
      _appLinksChannel.name,
      const StandardMethodCodec().encodeSuccessEnvelope(link),
      (_) {},
    );
  }

  for (final (name, link) in [
    ('affiliate', _affiliateLink),
    ('private-server', 'https://lantern.io/private-server?exp=invalid'),
  ]) {
    testWidgets('invalid $name link shows a message without navigating', (
      tester,
    ) async {
      await mountApp(tester);

      emitLink(link);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text(_invalidLinkMessage), findsOneWidget);
      expect(router.stack.map((page) => page.name), [Home.name]);
    });
  }

  testWidgets('cold-start rejection waits for the first route', (tester) async {
    guard.hold = true;
    await mountApp(tester);
    expect(guard.pending, isNotNull);
    expect(router.hasEntries, isFalse);
    expect(find.byType(Scaffold), findsNothing);

    emitLink(_affiliateLink);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text(_invalidLinkMessage), findsNothing);
    expect(router.hasEntries, isFalse);

    guard.release();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text(_invalidLinkMessage), findsOneWidget);
    expect(router.stack.map((page) => page.name), [Home.name]);
  });

  testWidgets('disposing a pending rejection does not show a message', (
    tester,
  ) async {
    guard.hold = true;
    await mountApp(tester);
    expect(guard.pending, isNotNull);

    emitLink(_affiliateLink);
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    guard.release();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text(_invalidLinkMessage), findsNothing);
  });

  testWidgets('duplicate rejected links do not queue a second message', (
    tester,
  ) async {
    await mountApp(tester);

    emitLink(_affiliateLink);
    emitLink(_affiliateLink);
    await tester.pumpAndSettle();
    expect(find.text(_invalidLinkMessage), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text(_invalidLinkMessage), findsNothing);
    expect(router.stack.map((page) => page.name), [Home.name]);
  });

  testWidgets('valid affiliate link still opens plans with a normalized code', (
    tester,
  ) async {
    await mountApp(tester);

    emitLink('https://lantern.io/affiliate/half');
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Plans: HALF'), findsOneWidget);
    expect(find.text(_invalidLinkMessage), findsNothing);
    expect(router.stack.map((page) => page.name), [Home.name, Plans.name]);
  });
}
