import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/core/common/app_eum.dart';

import '../utils/app_robot.dart';
import '../utils/vpn_robot.dart';

/// Android VPN smoke harnesses. Self-contained: app shell via [AppRobot], VPN
/// state via [VpnRobot] (which listens to vpnProvider). Does not use
/// vpn_smoke_helpers; the other platforms still do.

/// Shared per-scenario setup: launch, wait for the toggle, and reset to a
/// disconnected baseline (scenarios share one app process in the aggregate, so
/// this reset — not prior-test cleanup — is what guarantees a clean start).
/// Also starts the error watch and asserts (in a non-pumping tearDown) that the
/// VPN never entered an error state during the scenario.
Future<VpnRobot> _prepareVpnAtHome(WidgetTester tester) async {
  final app = AppRobot(tester);
  final vpn = VpnRobot(tester, app);
  await app.launchToHome();
  await app.waitForControlReady(vpn.vpnToggle, controlName: 'VPN toggle');
  await vpn.ensureDisconnected();

  vpn.beginErrorWatch();
  addTearDown(vpn.assertNoErrorsSeen);

  return vpn;
}

/// Connect/disconnect smoke.
Future<void> runAndroidConnectSmoke(WidgetTester tester) async {
  final vpn = await _prepareVpnAtHome(tester);
  await vpn.connect();
  await vpn.disconnectIfNeeded();
}

/// Connects and disconnects twice, asserting the VPN returns to a clean state
/// each time — catches races in repeated connect/disconnect transitions.
Future<void> runAndroidReconnectSmoke(WidgetTester tester) async {
  final vpn = await _prepareVpnAtHome(tester);
  for (var i = 0; i < 2; i++) {
    await vpn.connect();
    await vpn.disconnectIfNeeded();
  }
}

/// Connects and disconnects in full tunnel and smart routing. The public IP is
/// checked natively by VpnRoutingModeTest: Lantern excludes its own process
/// from the VPN, so a check from here never sees the tunnel.
Future<void> runAndroidRoutingModeSmoke(WidgetTester tester) async {
  final vpn = await _prepareVpnAtHome(tester);

  try {
    // A prior scenario in the same process may have left a different mode.
    await vpn.setRoutingMode(RoutingMode.smart);
    for (final mode in [RoutingMode.full, RoutingMode.smart]) {
      await vpn.setRoutingMode(mode);
      await vpn.connect();
      await vpn.disconnectIfNeeded();
    }
  } finally {
    // Don't leak full-tunnel into later scenarios sharing this process.
    await vpn.setRoutingMode(RoutingMode.smart);
  }
}
