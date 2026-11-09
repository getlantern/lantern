import 'dart:io';
import 'dart:ui' as ui;

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart' hide Onboarding;
import 'package:lantern/core/models/app_setting.dart';
import 'package:lantern/core/models/radiance_settings_state.dart';
import 'package:lantern/core/models/share_state.dart';
import 'package:lantern/core/router/router.dart';
import 'package:lantern/core/services/injection_container.dart';
import 'package:lantern/features/action_mode/provider/share_notifier.dart';
import 'package:lantern/features/helpers/provider/helpers_notifier.dart';
import 'package:lantern/features/home/provider/app_setting_notifier.dart';
import 'package:lantern/features/home/provider/feature_flag_notifier.dart';
import 'package:lantern/features/home/provider/radiance_settings_providers.dart';
import 'package:lantern/features/onboarding/onboarding.dart';

class _Settings extends AppSettingNotifier {
  _Settings([this.initial = const AppSetting()]);
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

class _Radiance extends RadianceSettings {
  final modes = <RoutingMode>[];

  @override
  RadianceSettingsState build() => const RadianceSettingsState();

  @override
  Future<Either<Failure, Unit>> setRoutingMode(RoutingMode mode) async {
    modes.add(mode);
    return right(unit);
  }
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
  Future<void> setAutoEnable(BuildContext context, bool enabled) async =>
      calls.add('setAutoEnable');
}

class _Router extends AppRouter {
  int pops = 0;
  final pushed = <PageRouteInfo>[];

  @override
  void pop<T extends Object?>([T? result]) => pops++;

  @override
  Future<T?> push<T extends Object?>(
    PageRouteInfo route, {
    OnNavigationFailure? onFailure,
  }) async {
    pushed.add(route);
    return null;
  }
}

class _Harness {
  _Harness(this.container, this.router, this.share, this.radiance);
  final ProviderContainer container;
  final _Router router;
  final _Share share;
  final _Radiance radiance;

  AppSetting get settings => container.read(appSettingProvider);

  _Flags get flags => container.read(featureFlagProvider.notifier) as _Flags;
}

const _boundaryKey = Key('onboarding.test.boundary');

Future<_Harness> _pump(
  WidgetTester tester, {
  bool invites = false,
  bool actionMode = false,
  AppSetting settings = const AppSetting(),
  ThemeData? theme,
  Size size = const Size(393, 852),
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  await sl.reset();
  final router = _Router();
  sl.registerSingleton<AppRouter>(router);
  addTearDown(sl.reset);
  final share = _Share();
  final radiance = _Radiance();
  final container = ProviderContainer(
    overrides: [
      appSettingProvider.overrideWith(() => _Settings(settings)),
      helperInvitesAvailableProvider.overrideWith(
        (ref) => ref.watch(featureFlagProvider)['helper_invites'] == true,
      ),
      featureFlagProvider.overrideWith(
        () => _Flags({
          if (actionMode) 'unbounded': true,
          if (invites) 'helper_invites': true,
        }),
      ),
      radianceSettingsProvider.overrideWith(() => radiance),
      shareProvider.overrideWith(() => share),
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
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: theme ?? AppTheme.appTheme(),
            home: const Onboarding(),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return _Harness(container, router, share, radiance);
}

Future<void> _continue(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('onboarding.primary')));
  await tester.pumpAndSettle();
}

Future<void> _whatMakesLanternDifferent(
  WidgetTester tester, {
  required bool invites,
}) async {
  await _pump(tester, invites: invites);
  await _continue(tester);
  expect(find.text('what_makes_lantern_different'.i18n), findsOneWidget);
}

/// Continues from the first page to the page after routing mode.
Future<void> _pastRoutingMode(WidgetTester tester) async {
  await _continue(tester);
  await _continue(tester);
  expect(find.text('choose_your_routing_mode'.i18n), findsOneWidget);
  await _continue(tester);
}

final _actionModePage = find.byKey(const Key('onboarding.action_mode'));
final _helpSomeone = find.byKey(
  const Key('onboarding.action_mode.help_someone'),
);

// The test font's square glyphs are far wider and taller than Urbanist, so
// the routing mode page overflows at the design's 393 x 852. Tests that walk
// the flow use room enough for it; the screenshot keeps the design's size.
const _flowSize = Size(600, 1400);

const _rowTitles = [
  'onboarding_action_mode_share',
  'onboarding_action_mode_help_someone',
  'onboarding_action_mode_privacy',
  'onboarding_action_mode_control',
];

void main() {
  setUpAll(Localization.loadTranslations);
  tearDown(() => HelpersNotifier.debugBuildEnabled = null);

  testWidgets('where Personal Proxies are offered, What makes Lantern '
      'different lists them with a New badge, before the nonprofit row', (
    tester,
  ) async {
    await _whatMakesLanternDifferent(tester, invites: true);
    final row = find.byKey(const Key('onboarding.personal_proxies'));
    expect(row, findsOneWidget);
    expect(
      find.descendant(
        of: row,
        matching: find.text('onboarding_personal_proxies'.i18n),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: row,
        matching: find.text('onboarding_personal_proxies_description'.i18n),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: row,
        matching: find.byKey(const Key('onboarding.new_badge')),
      ),
      findsOneWidget,
    );
    expect(
      tester.getTopLeft(row).dy,
      lessThan(tester.getTopLeft(find.text('nonprofit_mission'.i18n)).dy),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('elsewhere the row is not shown', (tester) async {
    await _whatMakesLanternDifferent(tester, invites: false);
    expect(find.byKey(const Key('onboarding.personal_proxies')), findsNothing);
  });

  testWidgets('outside censored regions, an Action Mode row sits between '
      'Private Servers and Nonprofit Mission where Action Mode is offered', (
    tester,
  ) async {
    HelpersNotifier.debugBuildEnabled = true;
    await _pump(tester, actionMode: true);
    await _continue(tester);
    final row = find.byKey(const Key('onboarding.action_mode_row'));
    expect(row, findsOneWidget);
    expect(
      find.descendant(
        of: row,
        matching: find.text('onboarding_action_mode_row_description'.i18n),
      ),
      findsOneWidget,
    );
    expect(
      tester.getTopLeft(row).dy,
      greaterThan(tester.getTopLeft(find.text('private_servers'.i18n)).dy),
    );
    expect(
      tester.getTopLeft(row).dy,
      lessThan(tester.getTopLeft(find.text('nonprofit_mission'.i18n)).dy),
    );
  });

  testWidgets('in censored regions Personal Proxies takes the Action Mode '
      "row's place", (tester) async {
    HelpersNotifier.debugBuildEnabled = true;
    await _pump(tester, actionMode: true, invites: true);
    await _continue(tester);
    expect(
      find.byKey(const Key('onboarding.personal_proxies')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('onboarding.action_mode_row')), findsNothing);
  });

  testWidgets('without Action Mode there is no Action Mode row', (
    tester,
  ) async {
    await _whatMakesLanternDifferent(tester, invites: false);
    expect(find.byKey(const Key('onboarding.action_mode_row')), findsNothing);
  });

  group('Action Mode page', () {
    testWidgets('where Action Mode is offered, it follows routing mode with '
        'its four rows, Help someone you know marked New', (tester) async {
      HelpersNotifier.debugBuildEnabled = true;
      await _pump(tester, actionMode: true, size: _flowSize);
      await _pastRoutingMode(tester);

      expect(_actionModePage, findsOneWidget);
      expect(find.text('unbounded'.i18n), findsOneWidget);
      expect(find.text('onboarding_action_mode_subtitle'.i18n), findsOneWidget);
      var lastTop = double.negativeInfinity;
      for (final key in _rowTitles) {
        final title = find.text(key.i18n);
        expect(title, findsOneWidget, reason: key);
        expect(
          find.text('${key}_description'.i18n),
          findsOneWidget,
          reason: key,
        );
        final top = tester.getTopLeft(title).dy;
        expect(top, greaterThan(lastTop), reason: key);
        lastTop = top;
      }
      expect(
        find.descendant(
          of: _helpSomeone,
          matching: find.byKey(const Key('onboarding.new_badge')),
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('onboarding.new_badge')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('its Continue finishes onboarding, and nothing on the way '
        'turns Action Mode on', (tester) async {
      HelpersNotifier.debugBuildEnabled = true;
      final h = await _pump(tester, actionMode: true, size: _flowSize);
      await _pastRoutingMode(tester);
      expect(_actionModePage, findsOneWidget);

      // The rows only explain: tapping one does nothing.
      for (final key in _rowTitles) {
        await tester.tap(find.text(key.i18n));
        await tester.pumpAndSettle();
      }
      expect(_actionModePage, findsOneWidget);
      expect(h.settings.onboardingCompleted, isFalse);

      await _continue(tester);
      expect(h.settings.onboardingCompleted, isTrue);
      expect(h.router.pops, 1);
      expect(h.radiance.modes, [RoutingMode.smart]);
      expect(h.share.calls, isEmpty);
      expect(h.settings.unboundedAutoEnable, isFalse);
    });

    testWidgets('where Action Mode is not offered, routing mode stays the '
        'last page', (tester) async {
      final h = await _pump(tester, invites: true, size: _flowSize);
      await _pastRoutingMode(tester);
      expect(_actionModePage, findsNothing);
      expect(h.settings.onboardingCompleted, isTrue);
      expect(h.router.pops, 1);
      expect(h.share.calls, isEmpty);
    });

    testWidgets('not shown to a user who hid the Action Mode tab', (
      tester,
    ) async {
      final h = await _pump(
        tester,
        actionMode: true,
        settings: const AppSetting(unboundedHidden: true),
        size: _flowSize,
      );
      await _pastRoutingMode(tester);
      expect(_actionModePage, findsNothing);
      expect(h.settings.onboardingCompleted, isTrue);
    });

    testWidgets('a flag that arrives during onboarding adds the page, and '
        'one that leaves after it was shown does not take it away', (
      tester,
    ) async {
      final h = await _pump(tester, size: _flowSize);
      await _continue(tester);
      h.flags.set({'unbounded': true});
      await tester.pumpAndSettle();
      await _continue(tester);
      await _continue(tester);
      expect(_actionModePage, findsOneWidget);

      h.flags.set({});
      await tester.pumpAndSettle();
      expect(_actionModePage, findsOneWidget);
      expect(h.settings.onboardingCompleted, isFalse);
      await _continue(tester);
      expect(h.settings.onboardingCompleted, isTrue);
    });

    testWidgets('a build without helper invites leaves out Help someone you '
        'know', (tester) async {
      HelpersNotifier.debugBuildEnabled = false;
      await _pump(tester, actionMode: true, size: _flowSize);
      await _pastRoutingMode(tester);
      expect(_actionModePage, findsOneWidget);
      expect(_helpSomeone, findsNothing);
      expect(
        find.text('onboarding_action_mode_help_someone'.i18n),
        findsNothing,
      );
      expect(find.byKey(const Key('onboarding.new_badge')), findsNothing);
      expect(find.text('onboarding_action_mode_share'.i18n), findsOneWidget);
      expect(find.text('onboarding_action_mode_control'.i18n), findsOneWidget);
    });
  });

  group('Personal Proxies introduction', () {
    testWidgets('finishing with the Action Mode page marks it seen', (
      tester,
    ) async {
      HelpersNotifier.debugBuildEnabled = true;
      final h = await _pump(tester, actionMode: true, size: _flowSize);
      await _pastRoutingMode(tester);
      expect(_actionModePage, findsOneWidget);
      expect(h.settings.personalProxiesIntroSeen, isFalse);
      await _continue(tester);
      expect(h.settings.onboardingCompleted, isTrue);
      expect(h.settings.personalProxiesIntroSeen, isTrue);
    });

    testWidgets('finishing with the Personal Proxies row marks it seen', (
      tester,
    ) async {
      final h = await _pump(tester, invites: true, size: _flowSize);
      await _pastRoutingMode(tester);
      expect(h.settings.onboardingCompleted, isTrue);
      expect(h.settings.personalProxiesIntroSeen, isTrue);
    });

    testWidgets('skipping from the first page leaves it unseen, though both '
        'were offered', (tester) async {
      HelpersNotifier.debugBuildEnabled = true;
      final h = await _pump(
        tester,
        invites: true,
        actionMode: true,
        size: _flowSize,
      );
      await tester.tap(find.byKey(const Key('onboarding.skip')));
      await tester.pumpAndSettle();
      expect(h.settings.onboardingCompleted, isTrue);
      expect(h.settings.personalProxiesIntroSeen, isFalse);
    });

    testWidgets('helper invites that arrive after What makes Lantern '
        'different do not count as the row seen', (tester) async {
      final h = await _pump(tester, size: _flowSize);
      await _continue(tester);
      await _continue(tester);
      expect(find.text('choose_your_routing_mode'.i18n), findsOneWidget);
      h.flags.set({'helper_invites': true});
      await tester.pumpAndSettle();
      await _continue(tester);
      expect(h.settings.onboardingCompleted, isTrue);
      expect(h.settings.personalProxiesIntroSeen, isFalse);
    });

    testWidgets('finishing without either leaves it unseen, for the '
        'introduction to catch flags that came late', (tester) async {
      final h = await _pump(tester, size: _flowSize);
      await _pastRoutingMode(tester);
      expect(h.settings.onboardingCompleted, isTrue);
      expect(h.settings.personalProxiesIntroSeen, isFalse);
    });
  });

  // Renders the page to a PNG to compare with the design. Runs only with
  // --dart-define=ONBOARDING_SHOTS=<dir> and ONBOARDING_FONTS=<a directory
  // holding Urbanist-*.ttf>.
  const shotsDir = String.fromEnvironment('ONBOARDING_SHOTS');
  const fontsDir = String.fromEnvironment('ONBOARDING_FONTS');
  testWidgets('screenshot', skip: shotsDir.isEmpty, (tester) async {
    HelpersNotifier.debugBuildEnabled = true;
    await tester.runAsync(() async {
      final loader = FontLoader('Urbanist');
      for (final f in Directory(fontsDir).listSync()) {
        final name = f.uri.pathSegments.last;
        if (name.startsWith('Urbanist-') && name.endsWith('.ttf')) {
          final bytes = File(f.path).readAsBytesSync();
          loader.addFont(Future.value(ByteData.sublistView(bytes)));
        }
      }
      await loader.load();
    });
    final base = AppTheme.appTheme();
    await _pump(
      tester,
      actionMode: true,
      theme: base.copyWith(
        textTheme: base.textTheme.apply(fontFamily: 'Urbanist'),
      ),
    );
    await _pastRoutingMode(tester);
    await tester.runAsync(() async {
      await precacheImage(
        const AssetImage(AppImagePaths.onboardingActionModeGlobe),
        tester.element(_actionModePage),
      );
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await tester.pumpAndSettle();
    // At the design's size every row fits above the button, unscrolled.
    expect(
      tester
          .getBottomLeft(
            find.text('onboarding_action_mode_control_description'.i18n),
          )
          .dy,
      lessThan(
        tester.getTopLeft(find.byKey(const Key('onboarding.primary'))).dy,
      ),
    );
    final boundary =
        tester.renderObject(find.byKey(_boundaryKey)) as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      Directory(shotsDir).createSync(recursive: true);
      File(
        '$shotsDir/action_mode_light.png',
      ).writeAsBytesSync(data!.buffer.asUint8List());
    });
  });
}
