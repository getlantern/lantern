import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/app_setting.dart';
import 'package:lantern/features/home/provider/app_setting_notifier.dart';
import 'package:lantern/features/share_my_connection/action_mode_widgets.dart';
import 'package:lantern/features/share_my_connection/share_my_connection.dart';

class _Share extends ShareNotifier {
  @override
  ShareState build() => const ShareState(
    active: true,
    mode: ShareMode.unbounded,
    activeCount: 9,
    totalCount: 219,
  );
  @override
  void replayCurrentPeers() {}
  @override
  Future<bool> ensureConsent(BuildContext context) async => consent;
  static bool consent = true;
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
  setUp(() => _Share.consent = true);

  Future<void> mount(
    WidgetTester tester,
    Widget child, {
    Size size = const Size(393, 852),
    double scale = 1,
    Brightness brightness = Brightness.light,
    bool animated = false,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appSettingProvider.overrideWith(_Settings.new),
          shareProvider.overrideWith(_Share.new),
        ],
        child: ScreenUtilInit(
          designSize: const Size(393, 852),
          child: MaterialApp(
            theme: ThemeData(brightness: brightness),
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
    );
    if (animated) {
      await tester.pump(const Duration(milliseconds: 300));
    } else {
      await tester.pumpAndSettle();
    }
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
        const UnboundedTab(),
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
        'controls remain usable at 360x640, scale $scale, $brightness',
        (tester) async {
          var about = 0;
          await mount(
            tester,
            ActionModePanel(
              globe: const SizedBox(),
              statusCard: status(),
              onAbout: () => about++,
            ),
            size: const Size(360, 640),
            scale: scale,
            brightness: brightness,
          );
          await tester.tap(
            find.text(
              'Help others bypass censorship by securely sharing your connection.',
            ),
          );
          expect(about, 1);
          await tester.ensureVisible(find.byType(Checkbox));
          await tester.tap(find.byType(Checkbox));
          await tester.pumpAndSettle();
          expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
          expect(tester.takeException(), isNull);
        },
      );
    }
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
}
