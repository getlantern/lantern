import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/app_dialog.dart';
import 'package:lantern/core/common/app_eum.dart';
import 'package:lantern/core/common/app_theme.dart';
import 'package:lantern/core/localization/i18n.dart';
import 'package:lantern/core/models/app_setting.dart';
import 'package:lantern/core/models/feature_flags.dart';
import 'package:lantern/core/router/router.dart';
import 'package:lantern/core/router/router.gr.dart';
import 'package:lantern/core/services/injection_container.dart';
import 'package:lantern/features/helpers/provider/helpers_notifier.dart';
import 'package:lantern/features/home/provider/app_setting_notifier.dart';
import 'package:lantern/features/home/provider/feature_flag_notifier.dart';
import 'package:lantern/features/home/startup_presentations.dart';
import 'package:lantern/features/onboarding/personal_proxies_intro.dart';
import 'package:lantern/features/user_message/user_message_route_observer.dart';

import '../../integration_test/vpn/vpn_smoke_helpers.dart';

void main() {
  setUpAll(Localization.loadTranslations);

  testWidgets('intro cleanup marks it seen before late flags can open it', (
    tester,
  ) async {
    final app = await _launchApp(tester);
    await clearPersonalProxiesIntroForSmoke(tester, finders: _finders);
    expect(app.settings.personalProxiesIntroSeen, isTrue);

    app.flags.set(_introFlags);
    await tester.pumpAndSettle();
    expect(_finders.personalProxiesIntro, findsNothing);
    expect(_finders.homeScreen, findsOneWidget);
  });

  testWidgets('intro cleanup closes an open intro and leaves Home usable', (
    tester,
  ) async {
    final app = await _launchApp(tester, flags: _introFlags);
    expect(_finders.personalProxiesIntro, findsOneWidget);

    await clearPersonalProxiesIntroForSmoke(tester, finders: _finders);
    await tester.pumpAndSettle();
    expect(_finders.personalProxiesIntro, findsNothing);
    expect(app.router.stack, hasLength(1));

    await tester.tap(_finders.vpnToggle);
    await tester.pump();
    expect(find.text('taps: 1'), findsOneWidget);
  });

  testWidgets('intro cleanup leaves onboarding and other settings alone', (
    tester,
  ) async {
    const firstLaunch = AppSetting(locale: 'fa_IR', successfulConnection: true);
    final app = await _launchApp(
      tester,
      settings: firstLaunch,
      flags: _introFlags,
    );
    app.router.pushPath('/onboarding');
    await tester.pumpAndSettle();
    expect(_finders.onboardingScreen, findsOneWidget);

    await clearPersonalProxiesIntroForSmoke(tester, finders: _finders);
    await tester.pumpAndSettle();
    expect(_finders.onboardingScreen, findsOneWidget);
    expect(app.router.stack, hasLength(2));
    expect(
      app.settings.toJson(),
      firstLaunch.copyWith(personalProxiesIntroSeen: true).toJson(),
    );
  });

  testWidgets('connect smoke confirms the VPN conflict dialog', (tester) async {
    await _showVpnPage(tester, conflict: true);
    await tester.tap(find.byKey(const Key('vpn.toggle')));

    await VpnStateFinders().waitFor(
      tester,
      expected: const [VPNStatus.connected],
      timeout: const Duration(seconds: 2),
      reason: 'Connect anyway did not start the VPN',
      allowVpnConflict: true,
    );
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('connect smoke also works without a VPN conflict', (
    tester,
  ) async {
    await _showVpnPage(tester, conflict: false);
    await tester.tap(find.byKey(const Key('vpn.toggle')));

    await VpnStateFinders().waitFor(
      tester,
      expected: const [VPNStatus.connected],
      timeout: const Duration(seconds: 2),
      reason: 'VPN did not connect',
      allowVpnConflict: true,
    );
  });

  testWidgets('waiting for disconnect does not confirm a VPN conflict', (
    tester,
  ) async {
    await _showVpnPage(tester, conflict: true);
    await tester.tap(find.byKey(const Key('vpn.toggle')));

    await VpnStateFinders().waitFor(
      tester,
      expected: const [VPNStatus.disconnected],
      timeout: const Duration(seconds: 2),
      reason: 'VPN should remain disconnected',
    );
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
  });
}

Future<void> _showVpnPage(WidgetTester tester, {required bool conflict}) async {
  var state = VPNStatus.disconnected;
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(390, 844),
      child: MaterialApp(
        theme: AppTheme.appTheme(),
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: Column(
              children: [
                Text(state.name, key: Key('vpn.status.${state.name}')),
                TextButton(
                  key: const Key('vpn.toggle'),
                  onPressed: () {
                    void connect() =>
                        setState(() => state = VPNStatus.connected);
                    if (!conflict) {
                      connect();
                      return;
                    }
                    AppDialog.vpnConflictDialog(
                      context: context,
                      onConnectAnyway: () {
                        Navigator.of(context).pop();
                        connect();
                      },
                    );
                  },
                  child: const Text('Connect'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

final _finders = VpnSmokeFinders();

// Past onboarding and the macOS system extension dialog.
const _existingUser = AppSetting(
  onboardingCompleted: true,
  showSplashScreen: false,
);
const _introFlags = {'personal_proxies_intro': true, 'helper_invites': true};

class _Settings extends AppSettingNotifier {
  _Settings(this.initial);
  final AppSetting initial;

  @override
  AppSetting build() => initial;

  @override
  Future<void> update(AppSetting updated) async => state = updated;
}

class _Flags extends FeatureFlagNotifier {
  _Flags(this.initial);
  final Map<String, dynamic> initial;

  @override
  Map<String, dynamic> build() => initial;

  void set(Map<String, dynamic> flags) => state = flags;
}

/// Stands in for Home: runs the real intro hook over a VPN toggle.
class _Home extends HookConsumerWidget {
  const _Home(this.routes, this.presentations);
  final UserMessageRouteObserver routes;
  final StartupPresentations presentations;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taps = useState(0);
    useEffect(() => presentations.close, const []);
    usePersonalProxiesIntro(context, ref, routes, presentations: presentations);
    return Scaffold(
      key: const Key('home.screen'),
      body: TextButton(
        key: const Key('vpn.toggle'),
        onPressed: () => taps.value++,
        child: Text('taps: ${taps.value}'),
      ),
    );
  }
}

Widget _onboardingPage(RouteData _) =>
    const Scaffold(key: Key('onboarding.screen'));

/// The app's router with a stand-in Home, the real intro, and onboarding.
class _Router extends AppRouter {
  _Router(this.routesObserver, this.presentations);
  final UserMessageRouteObserver routesObserver;
  final StartupPresentations presentations;

  @override
  List<AutoRoute> get routes => [
    AutoRoute(
      path: '/',
      page: PageInfo(
        'Home',
        builder: (_) => _Home(routesObserver, presentations),
      ),
    ),
    AutoRoute(path: '/personal-proxies-intro', page: PersonalProxiesIntro.page),
    AutoRoute(
      path: '/onboarding',
      page: const PageInfo('Onboarding', builder: _onboardingPage),
    ),
  ];
}

class _App {
  _App(this.container, this.router);
  final ProviderContainer container;
  final _Router router;

  AppSetting get settings => container.read(appSettingProvider);

  _Flags get flags => container.read(featureFlagProvider.notifier) as _Flags;
}

Future<_App> _launchApp(
  WidgetTester tester, {
  AppSetting settings = _existingUser,
  Map<String, dynamic> flags = const {},
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(600, 1400);
  addTearDown(tester.view.reset);
  await sl.reset();
  final observer = UserMessageRouteObserver();
  final presentations = StartupPresentations();
  final router = _Router(observer, presentations);
  sl.registerSingleton<AppRouter>(router);
  addTearDown(sl.reset);
  final container = ProviderContainer(
    overrides: [
      appSettingProvider.overrideWith(() => _Settings(settings)),
      featureFlagProvider.overrideWith(() => _Flags(flags)),
      helperInvitesAvailableProvider.overrideWith(
        (ref) =>
            ref.watch(featureFlagProvider).getBool(FeatureFlag.helperInvites),
      ),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: ScreenUtilInit(
        designSize: const Size(393, 852),
        child: MaterialApp.router(
          theme: AppTheme.appTheme(),
          routerConfig: router.config(navigatorObservers: () => [observer]),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return _App(container, router);
}
