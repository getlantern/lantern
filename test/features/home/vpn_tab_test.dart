import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:i18n_extension/i18n_extension.dart';
import 'package:i18n_extension_importer/i18n_extension_importer.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/datacap_info.dart';
import 'package:lantern/core/models/lantern_status.dart';
import 'package:lantern/core/models/macos_extension_state.dart';
import 'package:lantern/core/models/radiance_settings_state.dart';
import 'package:lantern/core/models/server_location.dart';
import 'package:lantern/features/helpers/models/helpers_view.dart';
import 'package:lantern/features/helpers/personal_proxy_banner.dart';
import 'package:lantern/features/helpers/provider/helpers_notifier.dart';
import 'package:lantern/features/home/provider/radiance_settings_providers.dart';
import 'package:lantern/features/home/vpn_tab.dart';
import 'package:lantern/features/macos_extension/provider/macos_extension_notifier.dart';
import 'package:lantern/features/vpn/provider/server_location_notifier.dart';
import 'package:lantern/features/vpn/provider/vpn_notifier.dart';
import 'package:lantern/lantern/lantern_service.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';

const _windowsSmokeTestTabViewport = Size(374, 569);
const _shortTabViewport = Size(374, 300);

class _FakeLanternService implements LanternService {
  @override
  Future<Either<Failure, DataCapUsageResponse>> getDataCapInfo() async {
    return right(
      DataCapUsageResponse(
        enabled: true,
        usage: DataCapUsageDetails(
          bytesAllotted: 1000,
          bytesUsed: 100,
          allotmentStartTime: '2026-08-25T00:00:00Z',
          allotmentEndTime: '2026-08-26T00:00:00Z',
        ),
      ),
    );
  }

  @override
  Stream<LanternStatus> watchVPNStatus() => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _WaitingHelpers extends HelpersNotifier {
  @override
  HelpersState build() => const HelpersState(
    viewLoaded: true,
    view: HelpersView(
      unlocked: true,
      helpers: [HelperPairingView(pairingId: 'p1', name: 'Ali')],
      invites: [HelperInviteView(id: 'i1', state: 'claimed', code: '2562')],
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Map<String, Map<String, String>> englishTranslations;
  setUpAll(() async {
    // Load assets outside each widget test's fake-async zone so a cached
    // asset future from one test cannot deadlock a subsequent test.
    englishTranslations = await GettextImporter().fromAssetFile(
      'en',
      'assets/locales/en.po',
    );
  });
  setUp(() {
    final previousTranslations = Localization.translations;
    final previousLocale = Localization.defaultLocale;
    addTearDown(() {
      Localization.translations = previousTranslations;
      Localization.defaultLocale = previousLocale;
    });
    Localization.translations =
        Translations.byLocale('en') + englishTranslations;
    Localization.defaultLocale = 'en';
  });

  for (final viewport in [
    (
      name: 'Windows smoke-test viewport',
      size: _windowsSmokeTestTabViewport,
      mustScroll: false,
    ),
    (name: 'short viewport', size: _shortTabViewport, mustScroll: true),
  ]) {
    for (final isPro in [false, true]) {
      testWidgets('keeps ${isPro ? 'Pro renewal' : 'free-user'} controls accessible '
          'at the ${viewport.name}', (tester) async {
        // MediaQuery and ScreenUtil should see the full application window. The
        // smaller box below represents the tab area left after the Windows chrome.
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = desktopWindowSize;
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              lanternServiceProvider.overrideWithValue(_FakeLanternService()),
              isUserProProvider.overrideWithValue(isPro),
              isUserExpiredProvider.overrideWithValue(false),
              proRenewalProvider.overrideWithValue(
                isPro
                    ? ProRenewalInfo(
                        ProRenewalState.expiresToday,
                        DateTime(2026, 9, 8),
                        0,
                      )
                    : ProRenewalInfo.none,
              ),
              serverLocationProvider.overrideWithValue(
                initialServerLocation().copyWith(
                  autoLocation: const AutoLocation(
                    country: '',
                    countryCode: '',
                    displayName: 'fastest_server',
                  ),
                ),
              ),
              radianceSettingsProvider.overrideWithValue(
                const RadianceSettingsState(),
              ),
              vpnProvider.overrideWithValue(VPNStatus.disconnected),
              macosExtensionProvider.overrideWithValue(
                const MacOSExtensionState(SystemExtensionStatus.activated),
              ),
            ],
            child: ScreenUtilInit(
              designSize: desktopWindowSize,
              child: MaterialApp(
                theme: AppTheme.appTheme(),
                home: Scaffold(
                  body: Align(
                    alignment: Alignment.topCenter,
                    child: SizedBox.fromSize(
                      size: viewport.size,
                      child: const VpnTab(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(tester.takeException(), isNull);
        expect(find.byType(ProBanner), findsOneWidget);
        final bannerAction = find.text(
          (isPro ? 'renew_pro' : 'upgrade_to_pro').i18n,
        );
        expect(bannerAction.hitTestable(), findsOneWidget);

        // Linux omits the split-tunneling row, so content may fit at the
        // smoke-test size. The shorter viewport must scroll on every platform.
        if (viewport.mustScroll) {
          final scrollableFinder = find.descendant(
            of: find.byType(SingleChildScrollView),
            matching: find.byType(Scrollable),
          );
          final scrollable = tester.state<ScrollableState>(scrollableFinder);
          expect(scrollable.position.maxScrollExtent, greaterThan(0));

          await tester.drag(
            find.byType(SingleChildScrollView),
            const Offset(0, -100),
          );
          await tester.pump(const Duration(milliseconds: 300));

          expect(scrollable.position.pixels, greaterThan(0));
        }

        for (final control in [
          find.byKey(const Key('vpn.toggle')),
          find.byKey(const Key('home.location_setting')),
          find.text('routing_mode'.i18n),
        ]) {
          await tester.ensureVisible(control);
          await tester.pump();
          expect(control.hitTestable(), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      });
    }
  }

  const withinWeek = ProRenewalInfo(ProRenewalState.withinWeek, null, 3);
  for (final (name, pro, renewal, banner) in [
    (
      'a Pro user sees the personal proxy banner',
      true,
      ProRenewalInfo.none,
      true,
    ),
    ('the Pro upsell wins for a free user', false, ProRenewalInfo.none, false),
    ('the renewal card wins for a Pro user', true, withinWeek, false),
  ]) {
    testWidgets(name, (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = desktopWindowSize;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            lanternServiceProvider.overrideWithValue(_FakeLanternService()),
            isUserProProvider.overrideWithValue(pro),
            isUserExpiredProvider.overrideWithValue(false),
            proRenewalProvider.overrideWithValue(renewal),
            personalProxyBannerVisibleProvider.overrideWithValue(true),
            serverLocationProvider.overrideWithValue(initialServerLocation()),
            radianceSettingsProvider.overrideWithValue(
              const RadianceSettingsState(),
            ),
            vpnProvider.overrideWithValue(VPNStatus.disconnected),
            macosExtensionProvider.overrideWithValue(
              const MacOSExtensionState(SystemExtensionStatus.activated),
            ),
          ],
          child: ScreenUtilInit(
            designSize: desktopWindowSize,
            child: MaterialApp(
              theme: AppTheme.appTheme(),
              home: const Scaffold(body: VpnTab()),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(
        find.byKey(const Key('vpn.personal_proxy_banner')),
        banner ? findsOneWidget : findsNothing,
      );
      if (banner) {
        expect(find.text('personal_proxy_banner_title'.i18n), findsOneWidget);
        expect(find.text('personal_proxy_banner_body'.i18n), findsOneWidget);
      }
    });
  }

  testWidgets('a friend waiting on approval takes the slot from the Pro '
      'upsell, for a user who has a personal proxy too', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = desktopWindowSize;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          lanternServiceProvider.overrideWithValue(_FakeLanternService()),
          isUserProProvider.overrideWithValue(false),
          isUserExpiredProvider.overrideWithValue(false),
          proRenewalProvider.overrideWithValue(ProRenewalInfo.none),
          helpersProvider.overrideWith(_WaitingHelpers.new),
          helperInvitesAvailableProvider.overrideWithValue(true),
          serverLocationProvider.overrideWithValue(initialServerLocation()),
          radianceSettingsProvider.overrideWithValue(
            const RadianceSettingsState(),
          ),
          vpnProvider.overrideWithValue(VPNStatus.disconnected),
          macosExtensionProvider.overrideWithValue(
            const MacOSExtensionState(SystemExtensionStatus.activated),
          ),
        ],
        child: ScreenUtilInit(
          designSize: desktopWindowSize,
          child: MaterialApp(
            theme: AppTheme.appTheme(),
            home: const Scaffold(body: VpnTab()),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(ProBanner), findsNothing);
    expect(find.byKey(const Key('vpn.personal_proxy_banner')), findsOneWidget);
    expect(
      find.text('personal_proxy_banner_waiting_title'.i18n),
      findsOneWidget,
    );
  });

  for (final (size, compact) in [
    (desktopWindowSize, false),
    (const Size(393, 560), true),
  ]) {
    testWidgets('the personal proxy banner at ${size.height.toInt()}dp tall '
        'is ${compact ? 'a compact pill' : 'the full card'}', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            personalProxyBannerVisibleProvider.overrideWithValue(true),
          ],
          child: ScreenUtilInit(
            designSize: size,
            child: MaterialApp(
              theme: AppTheme.appTheme(),
              home: const Scaffold(body: PersonalProxyBanner()),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(
        find.byKey(const Key('vpn.personal_proxy_banner')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('vpn.personal_proxy_banner.compact')),
        compact ? findsOneWidget : findsNothing,
      );
      expect(find.text('personal_proxy_banner_title'.i18n), findsOneWidget);
      expect(
        find.text('personal_proxy_banner_body'.i18n),
        compact ? findsNothing : findsOneWidget,
      );
      if (compact) {
        expect(
          tester
              .getSize(
                find.byKey(const Key('vpn.personal_proxy_banner.compact')),
              )
              .height,
          40,
        );
      }
    });
  }
}
