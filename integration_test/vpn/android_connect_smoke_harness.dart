import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/core/common/app_eum.dart';

import '../utils/app_robot.dart';
import '../utils/vpn_robot.dart';

/// Android VPN smoke harnesses. Self-contained: app shell via [AppRobot], VPN
/// state via [VpnRobot] (which listens to vpnProvider). Does not use
/// vpn_smoke_helpers; the other platforms still do.

const _ipCheckEndpoint = 'https://api64.ipify.org';

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

/// Asserts real traffic flows while connected (a reachable public endpoint),
/// not merely that the status flipped to connected.
Future<void> _expectTrafficFlows(String label) async {
  await _fetchPublicIpWithRetry(
    timeout: const Duration(seconds: 30),
    reason: '$label — no public traffic after connect',
  );
}

/// Asserts the public IP returns to [baselineIp] after disconnect, proving the
/// tunnel actually tore down (not just that the UI says disconnected).
/// Teardown propagation is slow on emulators (route table restore plus the
/// IP-check service catching up), so this window is deliberately generous —
/// longer than the 60s the connect direction gets.
Future<void> _expectIpRestored(String baselineIp, String label) async {
  final end = DateTime.now().add(const Duration(seconds: 90));
  while (DateTime.now().isBefore(end)) {
    if (await _fetchPublicIpOnce() == baselineIp) {
      return;
    }
    await Future<void>.delayed(const Duration(seconds: 2));
  }
  fail(
    '$label — public IP did not revert to baseline ($baselineIp) after disconnect',
  );
}

/// Connects, asserts the public IP changed, then disconnects. [label] tags the
/// logs / failure message so multi-step scenarios are legible.
Future<void> _connectAndExpectIpChange(
  VpnRobot vpn, {
  required String label,
}) async {
  final baselineIp = await _fetchPublicIpWithRetry(
    timeout: const Duration(seconds: 40),
    reason: '$label before connect',
  );
  debugPrint('IP check [$label]: before connect public IP = $baselineIp');

  String? connectedIp;
  await vpn.connect();
  await Future<void>.delayed(const Duration(seconds: 3));
  connectedIp = await _awaitChangedPublicIp(baselineIp);
  debugPrint(
    'IP check [$label]: after connect public IP = '
    '${connectedIp ?? 'unchanged ($baselineIp)'}',
  );
  expect(
    connectedIp,
    isNotNull,
    reason:
        'Public IP did not change after VPN connected in $label '
        '(baseline: $baselineIp)',
  );

  await vpn.disconnectIfNeeded();
  await _expectIpRestored(baselineIp, label);
}

/// Connect/disconnect smoke. With [enableIpCheck] it also asserts the public IP
/// changed while connected.
Future<void> runAndroidConnectSmoke(
  WidgetTester tester, {
  bool enableIpCheck = false,
}) async {
  final vpn = await _prepareVpnAtHome(tester);

  if (enableIpCheck) {
    await _connectAndExpectIpChange(vpn, label: 'connect smoke');
    return;
  }

  await vpn.connect();
  await _expectTrafficFlows('connect smoke');
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

/// Switches routing mode smart -> full -> smart, verifying the public IP
/// changes on connect in each mode.
Future<void> runAndroidRoutingModeIpChangeSmoke(WidgetTester tester) async {
  final vpn = await _prepareVpnAtHome(tester);

  try {
    // Establish a deterministic starting mode (a prior scenario in the same
    // process may have left it elsewhere), then smart -> full.
    await vpn.setRoutingMode(RoutingMode.smart);
    await vpn.setRoutingMode(RoutingMode.full);
    await _connectAndExpectIpChange(vpn, label: 'full tunnel');

    // full -> smart.
    await vpn.setRoutingMode(RoutingMode.smart);
    await _connectAndExpectIpChange(vpn, label: 'smart routing');
  } finally {
    // Don't leak full-tunnel into later scenarios sharing this process.
    await vpn.setRoutingMode(RoutingMode.smart);
  }
}

Future<String?> _fetchPublicIpOnce() async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 6);
  try {
    final request = await client.getUrl(Uri.parse(_ipCheckEndpoint));
    final response = await request.close().timeout(const Duration(seconds: 6));
    if (response.statusCode != HttpStatus.ok) {
      return null;
    }
    final body = await response
        .transform(const SystemEncoding().decoder)
        .join();
    final ip = body.trim();
    if (ip.isNotEmpty && InternetAddress.tryParse(ip) != null) {
      return ip;
    }
  } catch (_) {
    return null;
  } finally {
    client.close(force: true);
  }
  return null;
}

Future<String> _fetchPublicIpWithRetry({
  required Duration timeout,
  required String reason,
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    final ip = await _fetchPublicIpOnce();
    if (ip != null && ip.isNotEmpty) {
      return ip;
    }
    await Future<void>.delayed(const Duration(seconds: 2));
  }
  fail('Failed to fetch public IP: $reason');
}

/// Polls for the public IP to change away from [baselineIp] after connect,
/// returning the new IP once it differs, or null if it never changed in time.
Future<String?> _awaitChangedPublicIp(String baselineIp) async {
  final deadline = DateTime.now().add(const Duration(seconds: 60));
  while (DateTime.now().isBefore(deadline)) {
    final current = await _fetchPublicIpOnce();
    if (current != null && current.isNotEmpty && current != baselineIp) {
      return current;
    }
    await Future<void>.delayed(const Duration(seconds: 3));
  }
  return null;
}
