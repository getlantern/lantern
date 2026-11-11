import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart' hide Onboarding;
import 'package:lantern/core/models/app_setting.dart';
import 'package:lantern/core/models/feature_flags.dart';
import 'package:lantern/core/models/share_state.dart';
import 'package:lantern/core/router/router.dart';
import 'package:lantern/core/services/injection_container.dart';
import 'package:lantern/features/action_mode/provider/share_notifier.dart';
import 'package:lantern/features/helpers/provider/helpers_notifier.dart';
import 'package:lantern/features/home/provider/app_setting_notifier.dart';
import 'package:lantern/features/home/provider/feature_flag_notifier.dart';
import 'package:lantern/features/home/startup_presentations.dart';
import 'package:lantern/features/onboarding/personal_proxies_intro.dart';
import 'package:lantern/features/user_message/user_message_route_observer.dart';

class _Settings extends AppSettingNotifier {
  _Settings(this.initial);
  final AppSetting initial;

  @override
  AppSetting build() => initial;

  @override
  Future<void> update(AppSetting updated) async => state = updated;

  @override
  void setOnboardingCompleted(bool value) =>
      update(state.copyWith(onboardingCompleted: value));
}

class _Flags extends FeatureFlagNotifier {
  _Flags(this.initial);
  final Map<String, dynamic> initial;

  @override
  Map<String, dynamic> build() => initial;

  void set(Map<String, dynamic> flags) => state = flags;
}

/// Records every way Action Mode could be turned on.
class _Share extends ShareNotifier {
  final calls = <String>[];

  @override
  ShareState build() => const ShareState();

  @override
  Future<bool> ensureConsent(BuildContext context) async {
    calls.add('ensureConsent');
    return true;
  }

  @override
  Future<void> toggle(BuildContext? context, [WidgetRef? widgetRef]) async =>
      calls.add('toggle');

  @override
  Future<void> autoStart(WidgetRef widgetRef) async => calls.add('autoStart');

  @override
  Future<void> startForHelper(WidgetRef widgetRef) async =>
      calls.add('startForHelper');

  @override
  Future<bool> setAutoEnable(BuildContext context, bool enabled) async {
    calls.add('setAutoEnable');
    return enabled;
  }
}

/// Records every invite created.
class _Helpers extends HelpersNotifier {
  final invites = <String>[];

  @override
  HelpersState build() => const HelpersState();

  @override
  Future<HelperResult> createInvite(String name) async {
    invites.add(name);
    return HelperResult.failure('test');
  }
}

/// Stands in for Home: runs the hook, and closes its startup presentations
/// when it goes away, as Home does.
class _Host extends HookConsumerWidget {
  const _Host(this.routes, this.presentations);
  final UserMessageRouteObserver routes;
  final StartupPresentations presentations;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    useEffect(() => presentations.close, const []);
    usePersonalProxiesIntro(context, ref, routes, presentations: presentations);
    return const Scaffold(body: Text('home'));
  }
}

Widget _otherPage(RouteData _) => const Scaffold(body: Text('other'));

/// A real AppRouter with the host as home, the introduction, and one other
/// screen.
class _RealRouter extends AppRouter {
  _RealRouter(this.routesObserver, this.presentations);
  final UserMessageRouteObserver routesObserver;
  final StartupPresentations presentations;

  @override
  List<AutoRoute> get routes => [
    AutoRoute(
      path: '/',
      page: PageInfo(
        'Host',
        builder: (_) => _Host(routesObserver, presentations),
      ),
    ),
    AutoRoute(path: '/personal-proxies-intro', page: PersonalProxiesIntro.page),
    AutoRoute(
      path: '/other',
      page: const PageInfo('Other', builder: _otherPage),
    ),
  ];
}

class _Harness {
  _Harness(
    this.container,
    this.router,
    this.share,
    this.helpers,
    this.presentations,
  );
  final ProviderContainer container;
  final StartupPresentations presentations;
  final _RealRouter router;
  final _Share share;
  final _Helpers helpers;

  AppSetting get settings => container.read(appSettingProvider);

  _Flags get flags => container.read(featureFlagProvider.notifier) as _Flags;
}

// Past the macOS system extension dialog, as an existing user is.
const _existingUser = AppSetting(
  onboardingCompleted: true,
  showSplashScreen: false,
);
const _introOn = {'personal_proxies_intro': true};
const _actionMode = {..._introOn, 'unbounded': true};
const _invites = {..._introOn, 'helper_invites': true};
const _boundaryKey = Key('personal_proxies_intro.test.boundary');

Future<_Harness> _launch(
  WidgetTester tester, {
  AppSetting settings = _existingUser,
  Map<String, dynamic> flags = const {},
  ThemeData? theme,
  Size size = const Size(600, 1400),
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  await sl.reset();
  final observer = UserMessageRouteObserver();
  final presentations = StartupPresentations();
  final router = _RealRouter(observer, presentations);
  sl.registerSingleton<AppRouter>(router);
  addTearDown(sl.reset);
  final share = _Share();
  final helpers = _Helpers();
  final container = ProviderContainer(
    overrides: [
      appSettingProvider.overrideWith(() => _Settings(settings)),
      featureFlagProvider.overrideWith(() => _Flags(flags)),
      helperInvitesAvailableProvider.overrideWith(
        (ref) =>
            ref.watch(featureFlagProvider).getBool(FeatureFlag.helperInvites),
      ),
      shareProvider.overrideWith(() => share),
      helpersProvider.overrideWith(() => helpers),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: ScreenUtilInit(
        designSize: const Size(393, 852),
        child: RepaintBoundary(
          key: _boundaryKey,
          child: MaterialApp.router(
            debugShowCheckedModeBanner: false,
            theme: theme ?? AppTheme.appTheme(),
            routerConfig: router.config(navigatorObservers: () => [observer]),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return _Harness(container, router, share, helpers, presentations);
}

final _intro = find.byKey(const Key('personal_proxies_intro.screen'));
final _primary = find.byKey(const Key('personal_proxies_intro.primary'));
final _actionModePage = find.byKey(const Key('onboarding.action_mode'));
final _personalProxiesRow = find.byKey(
  const Key('onboarding.personal_proxies'),
);

void main() {
  setUpAll(Localization.loadTranslations);
  setUp(() => HelpersNotifier.debugBuildEnabled = true);
  tearDown(() => HelpersNotifier.debugBuildEnabled = null);

  testWidgets('an existing user where Action Mode is offered gets the Action '
      'Mode page once, and is marked as having seen it', (tester) async {
    final h = await _launch(tester, flags: _actionMode);
    expect(_intro, findsOneWidget);
    expect(_actionModePage, findsOneWidget);
    expect(
      find.byKey(const Key('onboarding.action_mode.help_someone')),
      findsOneWidget,
    );
    expect(_personalProxiesRow, findsNothing);
    expect(h.settings.personalProxiesIntroSeen, isTrue);
    expect(find.text('got_it'.i18n), findsOneWidget);

    // The next launch, with what this one saved.
    final saved = h.settings;
    await tester.pumpWidget(const SizedBox());
    await _launch(tester, settings: saved, flags: _actionMode);
    expect(_intro, findsNothing);
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('where Personal Proxies are offered, it shows What makes '
      'Lantern different with the Personal Proxies row marked New', (
    tester,
  ) async {
    final h = await _launch(tester, flags: _invites);
    expect(_intro, findsOneWidget);
    expect(_personalProxiesRow, findsOneWidget);
    expect(
      find.descendant(
        of: _personalProxiesRow,
        matching: find.byKey(const Key('onboarding.new_badge')),
      ),
      findsOneWidget,
    );
    expect(_actionModePage, findsNothing);
    expect(h.settings.personalProxiesIntroSeen, isTrue);
  });

  testWidgets('with both, What makes Lantern different comes first, then '
      'Continue leads to the Action Mode page and Got it closes', (
    tester,
  ) async {
    final h = await _launch(tester, flags: {..._invites, 'unbounded': true});
    expect(_personalProxiesRow, findsOneWidget);
    expect(find.text('continue'.i18n), findsOneWidget);
    await tester.tap(_primary);
    await tester.pumpAndSettle();
    expect(_actionModePage, findsOneWidget);
    expect(find.text('got_it'.i18n), findsOneWidget);
    await tester.tap(_primary);
    await tester.pumpAndSettle();
    expect(_intro, findsNothing);
    expect(find.text('home'), findsOneWidget);
    expect(h.router.stack, hasLength(1));
  });

  testWidgets('not shown while the personal_proxies_intro flag is off', (
    tester,
  ) async {
    final h = await _launch(tester, flags: {'unbounded': true});
    expect(_intro, findsNothing);
    expect(h.settings.personalProxiesIntroSeen, isFalse);
  });

  testWidgets('not shown to a user who has seen it', (tester) async {
    await _launch(
      tester,
      settings: _existingUser.copyWith(personalProxiesIntroSeen: true),
      flags: _actionMode,
    );
    expect(_intro, findsNothing);
  });

  testWidgets('not shown with nothing to introduce', (tester) async {
    final h = await _launch(tester, flags: _introOn);
    expect(_intro, findsNothing);
    expect(h.settings.personalProxiesIntroSeen, isFalse);
  });

  testWidgets('not shown to a user who hid the Action Mode tab', (
    tester,
  ) async {
    await _launch(
      tester,
      settings: _existingUser.copyWith(unboundedHidden: true),
      flags: _actionMode,
    );
    expect(_intro, findsNothing);
  });

  testWidgets('a build without helper invites has nothing to introduce', (
    tester,
  ) async {
    HelpersNotifier.debugBuildEnabled = false;
    await _launch(tester, flags: _actionMode);
    expect(_intro, findsNothing);
  });

  testWidgets('not shown before onboarding is done: onboarding introduces '
      'these itself', (tester) async {
    final h = await _launch(
      tester,
      settings: const AppSetting(),
      flags: _actionMode,
    );
    expect(_intro, findsNothing);
    expect(h.settings.personalProxiesIntroSeen, isFalse);
  });

  testWidgets('a run that showed onboarding leaves it for the next launch, '
      'even when the flags come after onboarding finished', (tester) async {
    final h = await _launch(
      tester,
      settings: const AppSetting(showSplashScreen: false),
    );
    h.container.read(appSettingProvider.notifier).setOnboardingCompleted(true);
    await tester.pumpAndSettle();
    h.flags.set(_actionMode);
    await tester.pumpAndSettle();
    expect(_intro, findsNothing);
    expect(h.settings.personalProxiesIntroSeen, isFalse);

    final saved = h.settings;
    await tester.pumpWidget(const SizedBox());
    await _launch(tester, settings: saved, flags: _actionMode);
    expect(_intro, findsOneWidget);
  });

  testWidgets('a macOS launch that opens the system extension dialog leaves '
      'it for the next launch', (tester) async {
    final h = await _launch(
      tester,
      settings: _existingUser.copyWith(showSplashScreen: true),
      flags: _actionMode,
    );
    expect(_intro, PlatformUtils.isMacOS ? findsNothing : findsOneWidget);
    expect(h.settings.personalProxiesIntroSeen, !PlatformUtils.isMacOS);
  });

  testWidgets('flags that arrive after the first frame open it then', (
    tester,
  ) async {
    final h = await _launch(tester);
    expect(_intro, findsNothing);
    h.flags.set(_actionMode);
    await tester.pumpAndSettle();
    expect(_intro, findsOneWidget);
    expect(_actionModePage, findsOneWidget);
    expect(h.settings.personalProxiesIntroSeen, isTrue);
  });

  group('with Home\'s startup popups', () {
    /// A startup popup, queued as Home queues its referral and renewal
    /// dialogs.
    Future<void> popup(_Harness h, String text) => showDialog<void>(
      context: h.router.navigatorKey.currentContext!,
      builder: (context) => AlertDialog(
        content: Text(text),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('close $text'),
          ),
        ],
      ),
    );

    testWidgets('a popup that comes while it is open waits until it closes', (
      tester,
    ) async {
      final h = await _launch(tester, flags: _actionMode);
      expect(_intro, findsOneWidget);
      h.presentations.add(() => popup(h, 'referral'));
      await tester.pumpAndSettle();
      expect(find.text('referral'), findsNothing);

      await tester.tap(_primary);
      await tester.pumpAndSettle();
      expect(_intro, findsNothing);
      expect(find.text('referral'), findsOneWidget);
    });

    testWidgets('it waits for a chain of popups to finish, gaps and all, '
        'then opens', (tester) async {
      final h = await _launch(tester);
      h.presentations.add(() async {
        await popup(h, 'referral');
        // A pause between the two, with nothing on screen.
        await Future<void>.delayed(const Duration(milliseconds: 500));
        await popup(h, 'renewal');
      });
      await tester.pumpAndSettle();
      expect(find.text('referral'), findsOneWidget);
      h.flags.set(_actionMode);
      await tester.pumpAndSettle();
      expect(_intro, findsNothing);

      await tester.tap(find.text('close referral'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(_intro, findsNothing);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(find.text('renewal'), findsOneWidget);
      expect(_intro, findsNothing);
      expect(h.settings.personalProxiesIntroSeen, isFalse);

      await tester.tap(find.text('close renewal'));
      await tester.pumpAndSettle();
      expect(_intro, findsOneWidget);
      expect(h.settings.personalProxiesIntroSeen, isTrue);
    });

    testWidgets('Home going away mid-chain runs nothing after it, without '
        'an error', (tester) async {
      final h = await _launch(tester);
      final held = Completer<void>();
      var after = false;
      h.presentations.add(() => held.future);
      h.flags.set(_actionMode);
      await tester.pumpAndSettle();
      h.presentations.add(() async => after = true);

      await tester.pumpWidget(const SizedBox());
      held.complete();
      await tester.pumpAndSettle();
      expect(after, isFalse);
      expect(h.settings.personalProxiesIntroSeen, isFalse);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('it waits while another screen covers home, and opens once '
      'that closes', (tester) async {
    final h = await _launch(tester);
    unawaited(h.router.pushPath('/other'));
    await tester.pumpAndSettle();
    h.flags.set(_actionMode);
    await tester.pumpAndSettle();
    expect(_intro, findsNothing);
    expect(find.text('other'), findsOneWidget);
    expect(h.settings.personalProxiesIntroSeen, isFalse);

    await h.router.maybePop();
    await tester.pumpAndSettle();
    expect(_intro, findsOneWidget);
  });

  testWidgets('it opens once a run: a flag that flickers does not open it '
      'again', (tester) async {
    final h = await _launch(tester, flags: _actionMode);
    await tester.tap(_primary);
    await tester.pumpAndSettle();
    expect(_intro, findsNothing);
    h.flags.set({});
    await tester.pumpAndSettle();
    h.container
        .read(appSettingProvider.notifier)
        .setPersonalProxiesIntroSeen(false);
    h.flags.set(_actionMode);
    await tester.pumpAndSettle();
    expect(_intro, findsNothing);
  });

  testWidgets('it turns nothing on: no Action Mode, no auto-enable, no '
      'invite', (tester) async {
    final h = await _launch(tester, flags: {..._invites, 'unbounded': true});
    for (final key in ['onboarding_personal_proxies', 'private_servers']) {
      await tester.tap(find.text(key.i18n));
      await tester.pumpAndSettle();
    }
    await tester.tap(_primary);
    await tester.pumpAndSettle();
    for (final key in [
      'onboarding_action_mode_share',
      'onboarding_action_mode_help_someone',
    ]) {
      await tester.tap(find.text(key.i18n));
      await tester.pumpAndSettle();
    }
    expect(_intro, findsOneWidget);
    await tester.tap(_primary);
    await tester.pumpAndSettle();
    expect(_intro, findsNothing);
    expect(h.share.calls, isEmpty);
    expect(h.helpers.invites, isEmpty);
    expect(h.settings.unboundedAutoEnable, isFalse);
  });

  testWidgets('system Back closes it without turning anything on', (
    tester,
  ) async {
    final h = await _launch(tester, flags: _actionMode);
    expect(_intro, findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(_intro, findsNothing);
    expect(find.text('home'), findsOneWidget);
    expect(h.share.calls, isEmpty);
  });

  // Renders the introduction to PNGs. Runs only with
  // --dart-define=ONBOARDING_SHOTS=<dir> and ONBOARDING_FONTS=<a directory
  // holding Urbanist-*.ttf>.
  const shotsDir = String.fromEnvironment('ONBOARDING_SHOTS');
  const fontsDir = String.fromEnvironment('ONBOARDING_FONTS');
  testWidgets('screenshots', skip: shotsDir.isEmpty, (tester) async {
    // Under the families GoogleFonts.urbanist names too, for the button.
    await tester.runAsync(() async {
      for (final (family, file) in [
        ('Urbanist', null),
        ('Urbanist_regular', 'Regular'),
        ('Urbanist_500', 'Medium'),
        ('Urbanist_600', 'SemiBold'),
        ('Urbanist_700', 'Bold'),
      ]) {
        final loader = FontLoader(family);
        for (final f in Directory(fontsDir).listSync()) {
          final name = f.uri.pathSegments.last;
          if (file == null
              ? name.startsWith('Urbanist-') && name.endsWith('.ttf')
              : name == 'Urbanist-$file.ttf') {
            final bytes = File(f.path).readAsBytesSync();
            loader.addFont(Future.value(ByteData.sublistView(bytes)));
          }
        }
        await loader.load();
      }
    });
    final base = AppTheme.appTheme();
    final theme = base.copyWith(
      textTheme: base.textTheme.apply(fontFamily: 'Urbanist'),
    );
    for (final (name, flags) in [
      ('intro_action_mode_light', _actionMode),
      ('intro_invites_light', _invites),
    ]) {
      await tester.pumpWidget(const SizedBox());
      await _launch(
        tester,
        flags: flags,
        theme: theme,
        size: const Size(393, 852),
      );
      expect(_intro, findsOneWidget);
      await tester.runAsync(() async {
        await precacheImage(
          const AssetImage(AppImagePaths.onboardingActionModeGlobe),
          tester.element(_intro),
        );
        await Future<void>.delayed(const Duration(milliseconds: 500));
      });
      await tester.pumpAndSettle();
      final boundary =
          tester.renderObject(find.byKey(_boundaryKey))
              as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        Directory(shotsDir).createSync(recursive: true);
        File(
          '$shotsDir/$name.png',
        ).writeAsBytesSync(data!.buffer.asUint8List());
      });
    }
  });
}
