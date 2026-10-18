import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/models/lantern_status.dart';
import 'package:lantern/core/models/macos_extension_state.dart';
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
  @override
  Stream<LanternStatus> build() => const Stream.empty();
}

void main() {
  tearDown(() => PlatformUtils.isTv = false);

  testWidgets('D-pad select toggles the VPN on TV', (tester) async {
    PlatformUtils.isTv = true;
    final vpn = _FakeVpnNotifier();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          vpnProvider.overrideWith(() => vpn),
          vPNStatusProvider.overrideWith(_FakeVpnStatus.new),
          macosExtensionProvider.overrideWithValue(
            const MacOSExtensionState(SystemExtensionStatus.activated),
          ),
        ],
        child: ScreenUtilInit(
          designSize: mobileSize,
          child: MaterialApp(
            home: Scaffold(body: Center(child: VPNSwitch())),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      FocusManager.instance.primaryFocus?.context,
      isNotNull,
      reason: 'the switch should autofocus on TV',
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(vpn.toggles, 1);
  });
}
