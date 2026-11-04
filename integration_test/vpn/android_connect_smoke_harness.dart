import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/core/common/app_eum.dart';

import '../utils/app_robot.dart';
import '../utils/public_ip_probe.dart';
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

/// Connect/disconnect smoke. With [checkPublicIp] it also checks that traffic
/// leaves through a proxy while connected and goes direct again afterwards.
Future<void> runAndroidConnectSmoke(
  WidgetTester tester, {
  bool checkPublicIp = false,
}) async {
  final vpn = await _prepareVpnAtHome(tester);
  if (!checkPublicIp) {
    await vpn.connect();
    await vpn.disconnectIfNeeded();
    return;
  }
  final direct = await _directPublicIp();
  await _connectAndExpectProxied(vpn, direct, label: 'connect smoke');
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

/// Switches routing mode full -> smart, checking in each that traffic leaves
/// through a proxy while connected and goes direct again afterwards.
Future<void> runAndroidRoutingModeIpChangeSmoke(WidgetTester tester) async {
  final vpn = await _prepareVpnAtHome(tester);

  try {
    // A prior scenario in the same process may have left a different mode.
    await vpn.setRoutingMode(RoutingMode.smart);
    final direct = await _directPublicIp();
    for (final mode in [RoutingMode.full, RoutingMode.smart]) {
      await vpn.setRoutingMode(mode);
      await _connectAndExpectProxied(vpn, direct, label: mode.name);
    }
  } finally {
    // Don't leak full-tunnel into later scenarios sharing this process.
    await vpn.setRoutingMode(RoutingMode.smart);
  }
}

Future<String> _directPublicIp() async =>
    (await awaitPublicIp('direct traffic before connecting', (p) => !p.vpn)).ip;

/// Connects, expects a VPN exit with an IP other than [directIp], then
/// disconnects and expects direct traffic again.
Future<void> _connectAndExpectProxied(
  VpnRobot vpn,
  String directIp, {
  required String label,
}) async {
  await vpn.connect();
  final tunneled = await awaitPublicIp(
    'proxied traffic in $label',
    (p) => p.vpn,
  );
  expect(
    tunneled.ip,
    isNot(directIp),
    reason: 'Public IP did not change in $label',
  );
  await vpn.disconnectIfNeeded();
  await awaitPublicIp('direct traffic after $label', (p) => !p.vpn);
}
