import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/lantern_status.dart';
import 'package:lantern/core/models/macos_extension_state.dart';
import 'package:lantern/features/action_mode/action_mode_widgets.dart';
import 'package:lantern/features/macos_extension/provider/macos_extension_notifier.dart';
import 'package:lantern/features/vpn/provider/vpn_notifier.dart';
import 'package:lantern/features/vpn/provider/vpn_status_notifier.dart';
import 'package:lantern/features/vpn/vpn_switch.dart';

class _FakeVpnNotifier extends VpnNotifier {
  @override
  VPNStatus build() => VPNStatus.disconnected;

  @override
  Future<Either<Failure, String>> onVPNStateChange() async => right('ok');
}

class _FakeVpnStatus extends VPNStatusNotifier {
  @override
  Stream<LanternStatus> build() => const Stream.empty();
}

void main() {
  tearDown(() => PlatformUtils.isTv = false);

  // Home's shape on TV: the switch in the body, the tab pill as bottom nav.
  testWidgets('D-pad moves from the VPN switch to the tab pill and back', (
    tester,
  ) async {
    PlatformUtils.isTv = true;
    final selected = <int>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          vpnProvider.overrideWith(_FakeVpnNotifier.new),
          vPNStatusProvider.overrideWith(_FakeVpnStatus.new),
          macosExtensionProvider.overrideWithValue(
            const MacOSExtensionState(SystemExtensionStatus.activated),
          ),
        ],
        child: ScreenUtilInit(
          designSize: mobileSize,
          child: MaterialApp(
            home: Scaffold(
              body: const Center(child: VPNSwitch()),
              bottomNavigationBar: ActionModeNavigation(
                selectedIndex: 0,
                onSelected: selected.add,
                vpnActive: false,
                actionActive: false,
                desktop: false,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // InkWell keeps its focus node private, so look up from the focused node.
    bool focused(Key key) =>
        FocusManager.instance.primaryFocus?.context
            ?.findAncestorWidgetOfExactType<InkWell>()
            ?.key ==
        key;
    const vpnTab = Key('action-mode.nav.0');
    const unboundedTab = Key('action-mode.nav.1');

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(focused(vpnTab), isTrue, reason: 'down from the switch');

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(focused(unboundedTab), isTrue, reason: 'right along the pill');

    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(selected, [1]);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      'VPNSwitch',
      reason: 'up returns to the switch',
    );
  });
}
