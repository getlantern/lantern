import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/app_setting.dart';
import 'package:lantern/core/models/share_state.dart';
import 'package:lantern/features/home/provider/app_setting_notifier.dart';
import 'package:lantern/features/action_mode/action_mode_widgets.dart';
import 'package:lantern/features/action_mode/auto_enable_mode.dart';
import 'package:lantern/features/action_mode/provider/share_notifier.dart';
import 'package:lantern/features/action_mode/action_mode.dart';

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
}
