import 'package:animated_toggle_switch/animated_toggle_switch.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/lantern_status.dart';
import 'package:lantern/core/models/macos_extension_state.dart';
import 'package:lantern/core/widgets/custom_app_bar.dart' as app_bar;
import 'package:lantern/core/widgets/app_tile.dart';
import 'package:lantern/core/widgets/switch_button.dart';
import 'package:lantern/core/widgets/setting_tile.dart';
import 'package:lantern/core/widgets/tv_shell.dart';
import 'package:lantern/features/macos_extension/provider/macos_extension_notifier.dart';
import 'package:lantern/features/vpn/provider/vpn_notifier.dart';
import 'package:lantern/features/vpn/provider/vpn_status_notifier.dart';
import 'package:lantern/features/vpn/vpn_switch.dart';

class _FakeVpnNotifier extends VpnNotifier {
  int toggles = 0;

  @override
  VPNStatus build() => VPNStatus.disconnected;

  @override
  Future<Either<Failure, String>> onVPNStateChange() async {
    toggles++;
    return right('ok');
  }
}

class _FakeVpnStatus extends VPNStatusNotifier {
  static StreamController<LanternStatus>? events;

  @override
  Stream<LanternStatus> build() => events?.stream ?? const Stream.empty();
}

void main() {
  setUp(() {
    PlatformUtils.isTv = true;
    PlatformUtils.debugTvShell = true;
  });
  tearDown(() {
    PlatformUtils.isTv = false;
    PlatformUtils.debugTvShell = null;
  });

  Widget rows(int count) => Scaffold(
    body: ListView(
      children: [
        for (var i = 0; i < count; i++)
          SettingTile(
            tileKey: Key('row$i'),
            label: 'row $i',
            value: '',
            icon: const Icon(Icons.info),
            actions: const [],
            onTap: () {},
          ),
      ],
    ),
  );

  Future<_FakeVpnNotifier> pumpShell(
    WidgetTester tester, {
    required String routeName,
    Widget? child,
    Size? panelSize,
    TextDirection? textDirection,
  }) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final vpn = _FakeVpnNotifier();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          vpnProvider.overrideWith(() => vpn),
          vPNStatusProvider.overrideWith(_FakeVpnStatus.new),
          isUserProProvider.overrideWithValue(false),
          macosExtensionProvider.overrideWithValue(
            const MacOSExtensionState(SystemExtensionStatus.activated),
          ),
        ],
        child: ScreenUtilInit(
          designSize: const Size(960, 540),
          child: MaterialApp(
            theme: AppTheme.darkTheme(),
            onGenerateRoute: (settings) => PageRouteBuilder<void>(
              settings: settings,
              pageBuilder: (_, _, _) {
                final shell = TvShell(
                  routeName: routeName,
                  child:
                      child ??
                      Builder(
                        builder: (context) {
                          panelSize = MediaQuery.sizeOf(context);
                          return rows(3);
                        },
                      ),
                );
                if (textDirection == null) return shell;
                return Directionality(
                  textDirection: textDirection,
                  child: shell,
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return vpn;
  }

  Widget rowsWithFooter(int count, double footer) => Scaffold(
    body: ListView(
      children: [
        for (var i = 0; i < count; i++)
          SettingTile(
            tileKey: Key('row$i'),
            label: 'row $i',
            value: '',
            icon: const Icon(Icons.info),
            actions: const [],
            onTap: () {},
          ),
        SizedBox(height: footer, child: const Text('footer')),
      ],
    ),
  );

  String? focusedLabel() => FocusManager.instance.primaryFocus?.debugLabel;

  // InkWell keeps its focus node private, so look up from the focused node.
  bool rowFocused(int i) =>
      FocusManager.instance.primaryFocus?.context
          ?.findAncestorWidgetOfExactType<InkWell>()
          ?.key ==
      Key('row$i');

  testWidgets('the screen gets a phone-width panel at the right', (
    tester,
  ) async {
    Size? seen;
    await pumpShell(
      tester,
      routeName: Home.name,
      child: Builder(
        builder: (context) {
          seen = MediaQuery.sizeOf(context);
          return const Scaffold(body: SizedBox());
        },
      ),
    );
    expect(
      seen,
      Size(960 - tvRightPanelX - tvSafeMarginH, 540 - tvSafeMarginV),
    );
    final panel = tester.getTopLeft(find.byType(Scaffold));
    expect(panel, const Offset(tvRightPanelX, tvSafeMarginV));
  });

  testWidgets('a sheet opened from a shell route fills the panel', (
    tester,
  ) async {
    await pumpShell(
      tester,
      routeName: Setting.name,
      child: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showAppBottomSheet(
              context: context,
              title: 'sheet',
              fitContent: true,
              builder: (_, _) =>
                  TextButton(onPressed: () {}, child: const Text('option')),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    expect(
      Focus.of(tester.element(find.text('open'))).hasPrimaryFocus,
      isTrue,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    final box = tester.getRect(find.byKey(const Key('bottomsheet.tv_box')));
    expect(box.left, tvRightPanelX);
    expect(box.right, 960 - tvSafeMarginH);
    expect(box.bottom, 540, reason: 'anchored to the screen bottom');
    expect(
      Focus.of(tester.element(find.text('option'))).hasPrimaryFocus,
      isTrue,
      reason: 'the sheet takes focus',
    );
    // A tap beside the box, inside the sheet's height, dismisses.
    await tester.tapAt(Offset(100, box.top + 10));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('bottomsheet.tv_box')), findsNothing);
    expect(
      Focus.of(tester.element(find.text('open'))).hasPrimaryFocus,
      isTrue,
      reason: 'focus returns to the opener',
    );
  });

  testWidgets('a screen whose rows load later lands on its first row', (
    tester,
  ) async {
    await pumpShell(tester, routeName: Home.name);
    final loaded = ValueNotifier(false);
    addTearDown(loaded.dispose);
    // Two marked controls, as on Apps split tunneling: the arrow and a
    // search icon.
    tester.state<NavigatorState>(find.byType(Navigator)).push(
      PageRouteBuilder<void>(
        pageBuilder: (_, _, _) => TvShell(
          routeName: Setting.name,
          child: ValueListenableBuilder<bool>(
            valueListenable: loaded,
            builder: (_, ready, _) => BaseScreen(
              title: 'Settings',
              appBar: CustomAppBar(
                title: const Text('Settings'),
                actions: [
                  TvNotInitialFocus(
                    child: IconButton(
                      key: const Key('search'),
                      icon: const Icon(Icons.search),
                      onPressed: () {},
                    ),
                  ),
                ],
              ),
              body: ready ? rows(2) : const SizedBox(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final placeholder = FocusManager.instance.primaryFocus!;
    expect(
      TvNotInitialFocus.skips(placeholder),
      isTrue,
      reason: 'a marked control holds focus while there is no row',
    );
    for (var i = 0; i < 4; i++) {
      await tester.pump();
      expect(
        FocusManager.instance.primaryFocus,
        same(placeholder),
        reason: 'focus does not cycle between the marked controls',
      );
    }
    loaded.value = true;
    await tester.pumpAndSettle();
    expect(rowFocused(0), isTrue, reason: 'the first row once it exists');
  });

  testWidgets('Left during loading, then Right once rows exist, lands on '
      'the first row', (tester) async {
    await pumpShell(tester, routeName: Home.name);
    final loaded = ValueNotifier(false);
    addTearDown(loaded.dispose);
    tester.state<NavigatorState>(find.byType(Navigator)).push(
      PageRouteBuilder<void>(
        pageBuilder: (_, _, _) => TvShell(
          routeName: Setting.name,
          child: ValueListenableBuilder<bool>(
            valueListenable: loaded,
            builder: (_, ready, _) => BaseScreen(
              title: 'Settings',
              body: ready ? rows(2) : const SizedBox(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(focusedLabel(), 'VPNSwitch');
    loaded.value = true;
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(rowFocused(0), isTrue, reason: 'not the loading placeholder');
  });

  for (final viaSwitch in [false, true]) {
    testWidgets('a row that appears after the deadline is left alone'
        '${viaSwitch ? ', also on Right from the switch' : ''}', (tester) async {
      var clock = DateTime(2026, 11, 24, 12);
      TvShell.now = () => clock;
      addTearDown(() => TvShell.now = DateTime.now);
      await pumpShell(tester, routeName: Home.name);
      final loaded = ValueNotifier(false);
      addTearDown(loaded.dispose);
      tester.state<NavigatorState>(find.byType(Navigator)).push(
        PageRouteBuilder<void>(
          pageBuilder: (_, _, _) => TvShell(
            routeName: Setting.name,
            child: ValueListenableBuilder<bool>(
              valueListenable: loaded,
              builder: (_, ready, _) => BaseScreen(
                title: 'Settings',
                body: ready ? rows(2) : const SizedBox(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final placeholder = FocusManager.instance.primaryFocus!;
      expect(TvNotInitialFocus.skips(placeholder), isTrue);
      // A retry is pending; the wait runs out before the rows come.
      await tester.pump();
      if (viaSwitch) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pumpAndSettle();
        expect(focusedLabel(), 'VPNSwitch');
      }
      clock = clock.add(TvShell.initialFocusWait + const Duration(seconds: 1));
      loaded.value = true;
      await tester.pumpAndSettle();
      if (viaSwitch) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pumpAndSettle();
      }
      expect(
        FocusManager.instance.primaryFocus,
        same(placeholder),
        reason: 'after the deadline the placeholder is the user\'s',
      );
    });
  }

  testWidgets('a row in a list inside a scrolling page stays in view after '
      'the inner list moves', (tester) async {
    // A tall header, then a 300dp list of rows that scrolls on its own.
    await pumpShell(
      tester,
      routeName: Setting.name,
      child: Scaffold(
        body: ListView(
          children: [
            const SizedBox(height: 600, child: Text('header')),
            SizedBox(height: 300, child: rows(10)),
          ],
        ),
      ),
    );
    Rect row(int i) => tester.getRect(find.byKey(Key('row$i')));
    const outerBottom = 540.0;
    expect(rowFocused(0), isTrue);
    expect(row(0).bottom, lessThanOrEqualTo(outerBottom));
    for (var i = 0; i < 6; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
    }
    expect(rowFocused(6), isTrue);
    expect(row(6).bottom, lessThanOrEqualTo(outerBottom));
    // Back up: the inner list scrolls its rows down in page coordinates,
    // and the page must follow.
    for (var i = 0; i < 6; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
    }
    expect(rowFocused(0), isTrue);
    expect(row(0).top, greaterThanOrEqualTo(0));
    expect(row(0).bottom, lessThanOrEqualTo(outerBottom));
  });

  testWidgets('a row with a toggle shows one ring: the control that has '
      'focus', (tester) async {
    await pumpShell(
      tester,
      routeName: Setting.name,
      child: Scaffold(
        body: ListView(
          children: [
            AppTile(
              tileKey: const Key('row0'),
              label: 'Block ads',
              onPressed: () {},
              trailing: SwitchButton(
                key: const Key('toggle'),
                value: false,
                onChanged: (_) {},
              ),
            ),
          ],
        ),
      ),
    );
    Border? rowRing() => (tester
            .widget<Container>(
              find
                  .ancestor(
                    of: find.byType(ListTile),
                    matching: find.byType(Container),
                  )
                  .first,
            )
            .foregroundDecoration as BoxDecoration?)
        ?.border as Border?;
    expect(rowRing(), isNotNull, reason: 'the row has focus');

    // The D-pad stops on the row in this step; give the toggle focus the
    // way a tap or a later per-screen step would.
    Focus.of(
      tester.element(
        find.descendant(
          of: find.byKey(const Key('toggle')),
          matching: find.byType(CustomAnimatedToggleSwitch<bool>),
        ),
      ),
    ).requestFocus();
    await tester.pumpAndSettle();
    final focused = FocusManager.instance.primaryFocus!;
    expect(
      focused.context!.findAncestorWidgetOfExactType<SwitchButton>(),
      isNotNull,
      reason: 'the toggle has focus',
    );
    expect(rowRing(), isNull, reason: 'the row ring goes out');
  });

  testWidgets('the back arrow points the other way in a right-to-left locale', (
    tester,
  ) async {
    await pumpShell(
      tester,
      routeName: Home.name,
      textDirection: TextDirection.rtl,
    );
    tester.state<NavigatorState>(find.byType(Navigator)).push(
      PageRouteBuilder<void>(
        pageBuilder: (_, _, _) => Directionality(
          textDirection: TextDirection.rtl,
          child: TvShell(
            routeName: Setting.name,
            child: BaseScreen(title: 'Settings', body: rows(2)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final flip = tester.widget<Transform>(
      find.descendant(
        of: find.byType(app_bar.BackButton),
        matching: find.byType(Transform),
      ),
    );
    expect(flip.transform.storage[0], -1.0, reason: 'mirrored on x');
  });

  testWidgets('a footer that does not fit never scrolls the row out of view', (
    tester,
  ) async {
    await pumpShell(
      tester,
      routeName: Setting.name,
      child: rowsWithFooter(3, 500),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(rowFocused(2), isTrue);
    final position = tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position;
    expect(position.pixels, 0, reason: 'no jump to the end');
    expect(
      tester.getRect(find.byKey(const Key('row2'))).top,
      greaterThanOrEqualTo(tvSafeMarginV),
    );
  });

  testWidgets('a sheet opened from a full-screen route sits under its column', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(960, 540),
        child: MaterialApp(
          theme: AppTheme.darkTheme(),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showAppBottomSheet(
                  context: context,
                  title: 'sheet',
                  fitContent: true,
                  builder: (_, _) => const Text('option'),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final box = tester.getRect(find.byKey(const Key('bottomsheet.tv_box')));
    expect(box.left, (960 - tvContentMaxWidth) / 2);
    expect(box.width, tvContentMaxWidth);
  });

  testWidgets('a VPN error is reported once with two shells mounted', (
    tester,
  ) async {
    final events = StreamController<LanternStatus>.broadcast();
    _FakeVpnStatus.events = events;
    addTearDown(() {
      _FakeVpnStatus.events = null;
      events.close();
    });
    await pumpShell(tester, routeName: Home.name);
    tester.state<NavigatorState>(find.byType(Navigator)).push(
      PageRouteBuilder<void>(
        pageBuilder: (_, _, _) =>
            TvShell(routeName: Setting.name, child: rows(2)),
      ),
    );
    await tester.pumpAndSettle();
    // The first shell stays mounted under the opaque route, offstage.
    expect(find.byType(VPNSwitch, skipOffstage: false), findsNWidgets(2));
    events.add(
      LanternStatus(status: VPNStatus.error, error: 'tunnel failed'),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('tunnel failed'), findsOneWidget);
    // The messenger queues snackbars one at a time: a second report would
    // follow the first, so clear it and look again.
    tester
        .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger))
        .removeCurrentSnackBar();
    await tester.pumpAndSettle();
    expect(find.text('tunnel failed'), findsNothing, reason: 'reported once');
  });

  testWidgets('a right-to-left locale keeps the switch on the left', (
    tester,
  ) async {
    await pumpShell(
      tester,
      routeName: Setting.name,
      textDirection: TextDirection.rtl,
    );
    expect(tester.getCenter(find.byType(VPNSwitch)).dx, lessThan(tvRightPanelX));
    final row = find.byKey(const Key('row0'));
    expect(tester.getTopLeft(row).dx, greaterThanOrEqualTo(tvRightPanelX));
    expect(
      Directionality.of(tester.element(row)),
      TextDirection.rtl,
      reason: 'the screen keeps its text direction',
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(focusedLabel(), 'VPNSwitch', reason: 'Left is still the switch');
  });

  testWidgets('Home starts on the switch; Right goes to the first row', (
    tester,
  ) async {
    final vpn = await pumpShell(tester, routeName: Home.name);
    expect(focusedLabel(), 'VPNSwitch');

    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(vpn.toggles, 1);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(rowFocused(0), isTrue);
  });

  testWidgets('other screens start on their first row', (tester) async {
    await pumpShell(tester, routeName: Setting.name);
    expect(rowFocused(0), isTrue);
  });

  testWidgets('the back arrow is reachable but never the first focus', (
    tester,
  ) async {
    await pumpShell(tester, routeName: Home.name);
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.push(
      PageRouteBuilder<void>(
        pageBuilder: (_, _, _) => TvShell(
          routeName: Setting.name,
          child: BaseScreen(title: 'Settings', body: rows(2)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(IconButton), findsOneWidget, reason: 'the arrow');
    expect(rowFocused(0), isTrue, reason: 'not the back arrow');

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    final focused = FocusManager.instance.primaryFocus!;
    expect(TvNotInitialFocus.skips(focused), isTrue, reason: 'Up reaches it');

    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(find.byType(IconButton), findsNothing, reason: 'Enter pops');
    expect(focusedLabel(), 'VPNSwitch', reason: 'Home gets the switch back');
  });

  testWidgets('Left goes to the switch and Right returns to the row left', (
    tester,
  ) async {
    await pumpShell(tester, routeName: Setting.name);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(rowFocused(2), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(focusedLabel(), 'VPNSwitch');

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(rowFocused(2), isTrue, reason: 'not the top of the list');
  });

  testWidgets('the last row scrolls the text after it into view', (
    tester,
  ) async {
    await pumpShell(
      tester,
      routeName: Setting.name,
      child: Scaffold(
        body: ListView(
          children: [
            for (var i = 0; i < 6; i++)
              SettingTile(
                tileKey: Key('row$i'),
                label: 'row $i',
                value: '',
                icon: const Icon(Icons.info),
                actions: const [],
                onTap: () {},
              ),
            const SizedBox(height: 120),
            const Text('Version 11.0.1', key: Key('version')),
          ],
        ),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
    }
    expect(rowFocused(5), isTrue);
    final version = tester.getRect(find.byKey(const Key('version')));
    expect(version.bottom, lessThanOrEqualTo(540 - tvSafeMarginV));
  });

  testWidgets('a closed dialog hands focus back to the row that opened it', (
    tester,
  ) async {
    await pumpShell(tester, routeName: Setting.name);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(rowFocused(1), isTrue);

    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.push(
      DialogRoute<void>(
        context: navigator.context,
        builder: (_) => const AlertDialog(content: Text('dialog')),
      ),
    );
    await tester.pumpAndSettle();
    expect(rowFocused(1), isFalse);

    navigator.pop();
    await tester.pumpAndSettle();
    expect(rowFocused(1), isTrue);
  });

  testWidgets('a closed dialog gives the switch back its focus', (
    tester,
  ) async {
    await pumpShell(tester, routeName: Home.name);
    expect(focusedLabel(), 'VPNSwitch');

    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.push(
      DialogRoute<void>(
        context: navigator.context,
        builder: (_) => const AlertDialog(content: Text('dialog')),
      ),
    );
    await tester.pumpAndSettle();
    navigator.pop();
    await tester.pumpAndSettle();
    expect(focusedLabel(), 'VPNSwitch');
  });
}
