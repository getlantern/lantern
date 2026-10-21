import 'dart:convert';
import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
// The public globe controller has no rotation readout. This deliberate internal
// import reads RotatingGlobeState; revisit when upgrading flutter_earth_globe.
import 'package:flutter_earth_globe/rotating_globe.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/app_setting.dart';
import 'package:lantern/core/models/relay_stats.dart';
import 'package:lantern/core/models/share_state.dart';
import 'package:lantern/core/widgets/info_row.dart';
import 'package:lantern/features/action_mode/action_mode_globe.dart';
import 'package:lantern/features/action_mode/peer_status_pill.dart';
import 'package:lantern/features/home/provider/app_setting_notifier.dart';
import 'package:lantern/features/action_mode/action_mode_widgets.dart';
import 'package:lantern/features/action_mode/advanced_stats_sheet.dart';
import 'package:lantern/features/action_mode/auto_enable_mode.dart';
import 'package:lantern/features/action_mode/provider/share_notifier.dart';
import 'package:lantern/features/action_mode/action_mode.dart';

class _Share extends ShareNotifier {
  _Share(this.initialState);

  final ShareState initialState;

  @override
  ShareState build() => initialState;
  @override
  void replayCurrentPeers() {}
  @override
  Future<bool> ensureConsent(BuildContext context) async => consent;
  @override
  Future<void> toggle(BuildContext context, WidgetRef widgetRef) async {
    toggles++;
  }

  static bool consent = true;
  static int toggles = 0;
}

class _Settings extends AppSettingNotifier {
  @override
  AppSetting build() =>
      const AppSetting(unboundedAutoEnable: false, unboundedWelcomeSeen: true);
  @override
  void setUnboundedAutoEnable(bool value) {
    state = state.copyWith(unboundedAutoEnable: value);
  }

  @override
  void setUnboundedWelcomeSeen(bool value) {
    state = state.copyWith(unboundedWelcomeSeen: value);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(Localization.loadTranslations);
  setUp(() {
    _Share.consent = true;
    _Share.toggles = 0;
  });

  Future<void> mount(
    WidgetTester tester,
    Widget child, {
    Size size = const Size(393, 852),
    double scale = 1,
    Brightness brightness = Brightness.light,
    bool animated = false,
    ShareState shareState = const ShareState(
      active: true,
      mode: ShareMode.unbounded,
      activeCount: 9,
      totalCount: 219,
    ),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    // The globe's origin lookup goes through package:http; answer it locally
    // so the test never touches the network.
    await http.runWithClient(
      () => tester.pumpWidget(
        ProviderScope(
          overrides: [
            appSettingProvider.overrideWith(_Settings.new),
            shareProvider.overrideWith(() => _Share(shareState)),
          ],
          child: ScreenUtilInit(
            designSize: const Size(393, 852),
            child: MaterialApp(
              theme: brightness == Brightness.dark
                  ? AppTheme.darkTheme()
                  : AppTheme.appTheme(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: Scaffold(body: child),
            ),
          ),
        ),
      ),
      () => MockClient(
        (_) async => http.Response(
          jsonEncode({
            'Location': {'Latitude': 37.77, 'Longitude': -122.41},
          }),
          200,
        ),
      ),
    );
    if (animated) {
      await tester.pump(const Duration(milliseconds: 300));
    } else {
      await tester.pumpAndSettle();
    }
  }

  for (final mode in [ShareMode.smc, ShareMode.unbounded]) {
    testWidgets('failed $mode stop is visible and can be retried', (
      tester,
    ) async {
      await mount(
        tester,
        const ActionModeTab(),
        shareState: ShareState(
          active: true,
          mode: mode,
          phase: mode == ShareMode.smc ? SharePhase.serving : SharePhase.idle,
          unboundedRunning: mode == ShareMode.unbounded,
          activeCount: 1,
          errorMessage: 'backend busy',
        ),
        animated: true,
      );
      final card = tester.widget<ActionModeStatusCard>(
        find.byType(ActionModeStatusCard),
      );
      expect(card.status, contains('backend busy'));
      expect(card.hasError, isTrue);
      expect(card.enabled, isTrue);
      final toggle = find.byKey(const Key('action-mode.toggle'));
      await tester.tapAt(tester.getCenter(toggle) - const Offset(20, 0));
      await tester.pump(const Duration(milliseconds: 300));
      expect(_Share.toggles, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  for (final scale in [1.0, 2.0]) {
    testWidgets('waiting pill stays below the intro at 320x568, scale $scale', (
      tester,
    ) async {
      await mount(
        tester,
        const ActionModeTab(),
        size: const Size(320, 568),
        scale: scale,
        shareState: const ShareState(active: true, mode: ShareMode.unbounded),
        animated: true,
      );
      expect(tester.takeException(), isNull);
      final pill = tester.getRect(find.byType(PeerStatusPill));
      final intro = tester.getRect(find.byType(InfoRow));
      final status = tester.getRect(find.byType(ActionModeStatusCard));
      expect(pill.top, greaterThanOrEqualTo(intro.bottom));
      expect(pill.bottom, lessThanOrEqualTo(status.top));
      expect(
        tester.getSize(find.byType(ActionModeGlobe)).height,
        greaterThan(0),
      );
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets(
    'content outside the globe scrolls on a small screen',
    (tester) async {
      await mount(
        tester,
        const ActionModeTab(),
        size: const Size(320, 568),
        scale: 2,
        animated: true,
      );
      final scroll = tester.state<ScrollableState>(
        find.descendant(
          of: find.byType(CustomScrollView),
          matching: find.byType(Scrollable),
        ),
      );
      expect(scroll.position.maxScrollExtent, greaterThan(0));
      final scrollBefore = scroll.position.pixels;

      await tester.drag(find.byType(InfoRow), const Offset(0, -100));
      await tester.pump(const Duration(milliseconds: 300));

      expect(scroll.position.pixels, greaterThan(scrollBefore));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
    variant: const TargetPlatformVariant({
      TargetPlatform.iOS,
      TargetPlatform.android,
    }),
  );

  for (final delta in [const Offset(-8, 0), const Offset(0, -8)]) {
    testWidgets(
      'globe owns touch drag $delta inside scroll view and pager',
      (tester) async {
        final tabs = TabController(length: 2, vsync: tester);
        addTearDown(tabs.dispose);
        await mount(
          tester,
          TabBarView(
            controller: tabs,
            children: const [ActionModeTab(), SizedBox()],
          ),
          animated: true,
        );
        final globe = find.byType(RotatingGlobe);
        final state = tester.state<RotatingGlobeState>(globe);
        tester.widget<RotatingGlobe>(globe).controller.stopRotation();
        final before = Offset(state.rotationZ, state.rotationX);
        final scroll = tester.state<ScrollableState>(
          find
              .descendant(
                of: find.byType(CustomScrollView),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        final scrollBefore = scroll.position.pixels;
        final gesture = await tester.startGesture(tester.getCenter(globe));
        for (var i = 0; i < 10; i++) {
          await gesture.moveBy(delta);
          await tester.pump(const Duration(milliseconds: 16));
        }
        await gesture.up();
        await tester.pump();
        expect(
          delta.dx != 0 ? state.rotationZ : state.rotationX,
          isNot(delta.dx != 0 ? before.dx : before.dy),
        );
        expect(scroll.position.pixels, scrollBefore);
        expect(tabs.animation!.value, 0);
      },
      variant: const TargetPlatformVariant({
        TargetPlatform.iOS,
        TargetPlatform.android,
      }),
    );
  }

  ActionModeStatusCard status({bool busy = false, VoidCallback? toggle}) =>
      ActionModeStatusCard(
        status: 'Disabled',
        enabled: false,
        ready: false,
        busy: busy,
        hasError: false,
        activeCount: 0,
        totalCount: 219,
        onToggle: toggle ?? () {},
      );

  testWidgets('busy switch blocks taps, drags, and semantic tap actions', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var toggles = 0;
    await mount(tester, status(busy: true, toggle: () => toggles++));
    final toggle = find.byKey(const Key('action-mode.toggle'));
    await tester.tapAt(tester.getCenter(toggle));
    await tester.dragFrom(tester.getCenter(toggle), const Offset(40, 0));
    await tester.pumpAndSettle();
    expect(toggles, 0);
    expect(
      tester
          .getSemantics(toggle)
          .getSemanticsData()
          .hasAction(SemanticsAction.tap),
      isFalse,
    );
    await mount(tester, status(toggle: () => toggles++));
    await tester.tapAt(tester.getCenter(toggle));
    await tester.pumpAndSettle();
    expect(toggles, 1);
    semantics.dispose();
  });

  testWidgets('keeps lifetime impact visible while sharing is disabled', (
    tester,
  ) async {
    await mount(tester, status());
    expect(find.text('219'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
    expect(find.text('Total people helped to date:'), findsOneWidget);
    expect(find.text('People you are helping right now:'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'actual Action Mode screen mounts with live state and welcome dialog scrolls',
    (tester) async {
      await mount(
        tester,
        const ActionModeTab(),
        size: const Size(360, 640),
        scale: 2,
        animated: true,
      );
      expect(find.text('9'), findsOneWidget);
      expect(find.text('219'), findsOneWidget);
      await tester.tap(
        find.text(
          'Help others bypass censorship by securely sharing your connection.',
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Welcome to Action Mode'), findsOneWidget);
      await tester.ensureVisible(find.text('Got It'));
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Got It'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('both auto-enable controls edit the same saved preference', (
    tester,
  ) async {
    await mount(
      tester,
      const Column(children: [ActionModeAutoEnable(), ActionModeAutoEnable()]),
    );
    expect(
      tester
          .widgetList<Checkbox>(find.byType(Checkbox))
          .every((c) => !c.value!),
      isTrue,
    );
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    expect(
      tester.widgetList<Checkbox>(find.byType(Checkbox)).every((c) => c.value!),
      isTrue,
    );
    await tester.tap(find.text('Auto-enable Action Mode').last);
    await tester.pumpAndSettle();
    expect(
      tester
          .widgetList<Checkbox>(find.byType(Checkbox))
          .every((c) => !c.value!),
      isTrue,
    );
  });

  testWidgets('declining consent leaves auto-enable off', (tester) async {
    _Share.consent = false;
    await mount(tester, const ActionModeAutoEnable());
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);
  });

  for (final scale in [1.0, 2.0]) {
    for (final brightness in Brightness.values) {
      testWidgets(
        'Action Mode tab controls stay usable at 360x640, scale $scale, $brightness',
        (tester) async {
          await mount(
            tester,
            const ActionModeTab(),
            size: const Size(360, 640),
            scale: scale,
            brightness: brightness,
            animated: true,
          );
          final toggle = find.byKey(const Key('action-mode.toggle'));
          await tester.ensureVisible(toggle);
          await tester.pump(const Duration(milliseconds: 300));
          // Sharing is on, so the knob sits right; tapping the current side
          // is a no-op for the switch. Tap the off side to toggle.
          await tester.tapAt(tester.getCenter(toggle) - const Offset(20, 0));
          await tester.pump(const Duration(milliseconds: 300));
          expect(_Share.toggles, 1);
          final link = find.byKey(const Key('action-mode.advanced-stats'));
          await tester.ensureVisible(link);
          await tester.pump(const Duration(milliseconds: 300));
          await tester.tap(link);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 500));
          expect(find.byType(AdvancedStatsView), findsOneWidget);
          // Auto-enable lives in Action Mode settings, not on the tab.
          expect(find.byType(ActionModeAutoEnable), findsNothing);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }

  for (final scale in [1.0, 2.0, 3.0]) {
    testWidgets('desktop AppBar contains full labels at text scale $scale', (
      tester,
    ) async {
      await mount(
        tester,
        Builder(
          builder: (context) => Scaffold(
            appBar: AppBar(
              bottom: PreferredSize(
                preferredSize: Size.fromHeight(
                  ActionModeNavigation.desktopHeight(context),
                ),
                child: ActionModeNavigation(
                  selectedIndex: 0,
                  onSelected: (_) {},
                  vpnActive: false,
                  actionActive: true,
                  desktop: true,
                ),
              ),
            ),
          ),
        ),
        size: const Size(800, 640),
        scale: scale,
      );
      final label = find.text('Action Mode');
      final element = tester.element(label);
      final painter = TextPainter(
        text: TextSpan(
          text: 'Action Mode',
          style: tester.widget<Text>(label).style,
        ),
        textDirection: TextDirection.ltr,
        textScaler: MediaQuery.textScalerOf(element),
        maxLines: 1,
      )..layout();
      expect(
        tester.getSize(label).height,
        greaterThanOrEqualTo(painter.height),
      );
      painter.dispose();
      final labelRect = tester.getRect(label);
      final navRect = tester.getRect(find.byType(ActionModeNavigation));
      final appBarRect = tester.getRect(find.byType(AppBar));
      expect(navRect.contains(labelRect.topLeft), isTrue);
      expect(navRect.contains(labelRect.bottomRight), isTrue);
      expect(appBarRect.bottom, greaterThanOrEqualTo(navRect.bottom));
      expect(tester.takeException(), isNull);
    });
  }

  for (final desktop in [false, true]) {
    testWidgets(
      'navigation selects Action Mode with large text, desktop=$desktop',
      (tester) async {
        var selected = 0;
        await mount(
          tester,
          StatefulBuilder(
            builder: (context, setState) => ActionModeNavigation(
              selectedIndex: selected,
              onSelected: (value) => setState(() => selected = value),
              vpnActive: false,
              actionActive: true,
              desktop: desktop,
            ),
          ),
          size: const Size(360, 640),
          scale: 2,
        );
        await tester.tap(find.byKey(const Key('action-mode.nav.1')));
        await tester.pumpAndSettle();
        expect(selected, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }

  const relay = RelayStats(
    available: true,
    speedDown: 1260000,
    speedUp: 48000,
    sessionDown: 340000000,
    sessionUp: 12000000,
    lifetimeDown: 1200000000,
    lifetimeUp: 30000000,
    countries: {
      'IR': RelayCountryStats(
        code: 'IR',
        name: 'Iran',
        down: 900000000,
        up: 20000000,
        people: 4,
      ),
      'RU': RelayCountryStats(
        code: 'RU',
        name: 'Russia',
        down: 200000000,
        up: 5000000,
        people: 1,
      ),
      '': RelayCountryStats(code: '', down: 1000),
    },
  );

  for (final brightness in Brightness.values) {
    testWidgets('advanced stats link opens the sheet ($brightness)', (
      tester,
    ) async {
      await mount(
        tester,
        const ActionModeTab(),
        brightness: brightness,
        shareState: const ShareState(
          active: true,
          mode: ShareMode.unbounded,
          unboundedRunning: true,
          relay: relay,
        ),
        animated: true,
      );
      final link = find.byKey(const Key('action-mode.advanced-stats'));
      await tester.ensureVisible(link);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(link);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(AdvancedStatsView), findsOneWidget);
      expect(find.text('↓ 1.3 MB/s  ↑ 48 kB/s'), findsOneWidget);
      expect(find.text('352 MB'), findsOneWidget);
      expect(find.text('1.2 GB'), findsOneWidget);
      expect(find.text('920 MB · 4 people'), findsOneWidget);
      expect(find.text('205 MB · 1 person'), findsOneWidget);
      expect(find.text('Unknown'), findsOneWidget);
      expect(find.text('1.0 kB'), findsOneWidget);
      expect(find.textContaining('0 people'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('advanced stats orders countries by data', (tester) async {
    await mount(
      tester,
      const AdvancedStatsView(),
      shareState: const ShareState(
        active: true,
        mode: ShareMode.unbounded,
        relay: relay,
      ),
    );
    final iran = tester.getTopLeft(find.text('Iran')).dy;
    final russia = tester.getTopLeft(find.text('Russia')).dy;
    final unknown = tester.getTopLeft(find.text('Unknown')).dy;
    expect(iran, lessThan(russia));
    expect(russia, lessThan(unknown));
    expect(find.byKey(const Key('advanced-stats.smc-note')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a country with people but no bytes shows people only', (
    tester,
  ) async {
    await mount(
      tester,
      const AdvancedStatsView(),
      shareState: const ShareState(
        active: true,
        mode: ShareMode.smc,
        phase: SharePhase.serving,
        relay: RelayStats(
          countries: {
            'IR': RelayCountryStats(code: 'IR', name: 'Iran', people: 1),
          },
        ),
      ),
    );
    expect(find.text('1 person'), findsOneWidget);
    expect(find.text('0 B · 1 person'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('advanced stats shows an empty state at large text', (
    tester,
  ) async {
    await mount(
      tester,
      const AdvancedStatsView(),
      size: const Size(320, 568),
      scale: 2,
      shareState: const ShareState(
        relay: RelayStats(available: true, speedDown: 1260000, speedUp: 48000),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('0 B'), findsWidgets);
    final empty = find.text(
      'No one helped yet. Countries will appear here once people connect '
      'through you.',
    );
    await tester.dragUntilVisible(
      empty,
      find.byKey(const Key('advanced-stats.list')),
      const Offset(0, -200),
    );
    expect(empty, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('advanced stats in SmC shows the same figures as WebRTC', (
    tester,
  ) async {
    await mount(
      tester,
      const AdvancedStatsView(),
      shareState: const ShareState(
        active: true,
        mode: ShareMode.smc,
        phase: SharePhase.serving,
        relay: relay,
      ),
    );
    expect(find.text('Direct connection'), findsOneWidget);
    expect(find.text('↓ 1.3 MB/s  ↑ 48 kB/s'), findsOneWidget);
    expect(find.text('352 MB'), findsOneWidget);
    expect(find.text('1.2 GB'), findsOneWidget);
    expect(find.text('920 MB · 4 people'), findsOneWidget);
    expect(
      find.text('Data stats are available only when sharing via Unbounded.'),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  for (final (mode, label) in [
    (ShareMode.unbounded, 'Enabled · WebRTC'),
    (ShareMode.smc, 'Enabled · Direct connection'),
  ]) {
    testWidgets('status line names the $mode mode', (tester) async {
      await mount(
        tester,
        const ActionModeTab(),
        shareState: ShareState(
          active: true,
          mode: mode,
          phase: mode == ShareMode.smc ? SharePhase.serving : SharePhase.idle,
          unboundedRunning: mode == ShareMode.unbounded,
        ),
        animated: true,
      );
      final card = tester.widget<ActionModeStatusCard>(
        find.byType(ActionModeStatusCard),
      );
      expect(card.status, label);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('advanced stats explains a fallback to WebRTC', (tester) async {
    await mount(
      tester,
      const AdvancedStatsView(),
      shareState: const ShareState(
        active: true,
        mode: ShareMode.unbounded,
        unboundedRunning: true,
        fallbackReason: "Your router isn't forwarding traffic.",
        relay: relay,
      ),
    );
    final mode = find.byKey(const Key('advanced-stats.mode'));
    expect(
      find.descendant(of: mode, matching: find.text('WebRTC')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: mode,
        matching: find.text(
          "Direct connection unavailable: Your router isn't forwarding "
          'traffic.',
        ),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
