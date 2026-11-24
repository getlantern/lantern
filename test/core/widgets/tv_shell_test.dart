import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/lantern_status.dart';
import 'package:lantern/core/models/macos_extension_state.dart';
import 'package:lantern/core/widgets/setting_tile.dart';
import 'package:lantern/core/widgets/tv_shell.dart';
import 'package:lantern/features/macos_extension/provider/macos_extension_notifier.dart';
import 'package:lantern/features/vpn/provider/vpn_notifier.dart';
import 'package:lantern/features/vpn/provider/vpn_status_notifier.dart';

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
  @override
  Stream<LanternStatus> build() => const Stream.empty();
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
              pageBuilder: (_, _, _) => TvShell(
                routeName: routeName,
                child:
                    child ??
                    Builder(
                      builder: (context) {
                        panelSize = MediaQuery.sizeOf(context);
                        return rows(3);
                      },
                    ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return vpn;
  }

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
