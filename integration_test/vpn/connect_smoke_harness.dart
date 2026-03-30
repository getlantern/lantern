import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/core/common/app_eum.dart';

import '../utils/widget_wait_utils.dart';
import 'vpn_smoke_helpers.dart';

const _vpnStateLabels = <VPNStatus, String>{
  VPNStatus.connected: 'Connected',
  VPNStatus.disconnected: 'Disconnected',
  VPNStatus.connecting: 'Connecting',
  VPNStatus.disconnecting: 'Disconnecting',
  VPNStatus.missingPermission: 'MissingPermission',
  VPNStatus.error: 'Error',
};

const _ipCheckEndpoint = 'https://api64.ipify.org';

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
      debugPrint('IP check: fetched public IP for $reason');
      return ip;
    }
    await Future<void>.delayed(const Duration(seconds: 2));
  }
  fail('Failed to fetch public IP: $reason');
}

Future<void> _assertPublicIpChangesFromBaseline(String baselineIp) async {
  final deadline = DateTime.now().add(const Duration(seconds: 60));
  while (DateTime.now().isBefore(deadline)) {
    final current = await _fetchPublicIpOnce();
    if (current != null && current.isNotEmpty && current != baselineIp) {
      debugPrint('IP check: detected public IP change after connect');
      return;
    }
    await Future<void>.delayed(const Duration(seconds: 3));
  }
  fail('Public IP did not change after VPN connected (baseline: $baselineIp)');
}

Future<void> runConnectSmokeHarness(
  WidgetTester tester, {
  bool enableIpCheck = false,
}) async {
  final finders = VpnSmokeFinders();
  final vpnStateFinders = VpnStateFinders(textLabels: _vpnStateLabels);
  String? baselinePublicIp;

  await waitForHomeReadyForVpnSmoke(tester, finders: finders);

  var vpnState = await resolveInitialStableVpnStateForSmoke(
    tester,
    finders: finders,
    vpnStateFinders: vpnStateFinders,
  );

  if (vpnState == VPNStatus.error) {
    fail('VPN reported error before connect/disconnect smoke');
  }
  if (vpnState == VPNStatus.missingPermission) {
    fail('VPN reported missing permission before connect/disconnect smoke');
  }

  if (vpnState == VPNStatus.connected) {
    await tester.tap(finders.vpnToggle);
    await tester.pump(const Duration(milliseconds: 200));

    await vpnStateFinders.waitFor(
      tester,
      expected: const [VPNStatus.disconnected],
      timeout: const Duration(seconds: 45),
      reason: 'Failed to reach disconnected state before connect test',
    );
  }

  if (enableIpCheck) {
    debugPrint('IP check: enabled; fetching baseline before connect');
    baselinePublicIp = await _fetchPublicIpWithRetry(
      timeout: const Duration(seconds: 40),
      reason: 'before connect',
    );
  }

  await tester.tap(finders.vpnToggle);
  await tester.pump(const Duration(milliseconds: 200));

  await vpnStateFinders.waitFor(
    tester,
    expected: const [VPNStatus.connected],
    timeout: const Duration(seconds: 45),
    reason: 'VPN did not reach connected state within 45 seconds',
  );

  if (enableIpCheck && baselinePublicIp != null) {
    debugPrint('IP check: waiting for IP change after connect');
    await Future<void>.delayed(const Duration(seconds: 3));
    await _assertPublicIpChangesFromBaseline(baselinePublicIp);
    debugPrint('IP check: passed');
  }

  await WidgetWaitUtils.waitForFinder(
    tester,
    finders.vpnToggle,
    timeout: const Duration(seconds: 15),
    reason: 'VPN toggle not available for disconnect',
  );
  await tester.tap(finders.vpnToggle);
  await tester.pump(const Duration(milliseconds: 200));

  await vpnStateFinders.waitFor(
    tester,
    expected: const [VPNStatus.disconnected],
    timeout: const Duration(seconds: 45),
    reason: 'VPN did not return to disconnected state within 45 seconds',
  );
}
