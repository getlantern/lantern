import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/core/common/app_eum.dart';

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

Future<bool> _didPublicIpChangeFromBaseline(String baselineIp) async {
  final deadline = DateTime.now().add(const Duration(seconds: 60));
  while (DateTime.now().isBefore(deadline)) {
    final current = await _fetchPublicIpOnce();
    if (current != null && current.isNotEmpty && current != baselineIp) {
      debugPrint('IP check: detected public IP change after connect');
      return true;
    }
    await Future<void>.delayed(const Duration(seconds: 3));
  }
  return false;
}

Future<void> _disconnectVpn(
  WidgetTester tester, {
  required Finder vpnToggle,
  required VpnStateFinders vpnStateFinders,
}) async {
  final currentState = vpnStateFinders.current();
  if (currentState != VPNStatus.connected &&
      currentState != VPNStatus.connecting) {
    return;
  }

  await tester.tap(vpnToggle);
  await tester.pump(const Duration(milliseconds: 200));

  await vpnStateFinders.waitFor(
    tester,
    expected: const [VPNStatus.disconnected],
    timeout: const Duration(seconds: 45),
    reason: 'VPN did not return to disconnected state within 45 seconds',
  );
}

Future<void> runConnectSmokeHarness(
  WidgetTester tester, {
  bool enableIpCheck = false,
}) async {
  final finders = VpnSmokeFinders();
  final vpnStateFinders = VpnStateFinders(textLabels: _vpnStateLabels);
  String? baselinePublicIp;

  await prepareVpnStartsDisconnectedForSmoke(
    tester,
    finders: finders,
    vpnStateFinders: vpnStateFinders,
    scenario: 'connect/disconnect smoke',
  );

  if (enableIpCheck) {
    debugPrint('IP check: enabled; fetching baseline before connect');
    baselinePublicIp = await _fetchPublicIpWithRetry(
      timeout: const Duration(seconds: 40),
      reason: 'before connect',
    );
  }

  var ipChanged = true;
  try {
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
      ipChanged = await _didPublicIpChangeFromBaseline(baselinePublicIp);
      if (ipChanged) {
        debugPrint('IP check: passed');
      }
    }
  } finally {
    await _disconnectVpn(
      tester,
      vpnToggle: finders.vpnToggle,
      vpnStateFinders: vpnStateFinders,
    );
  }

  if (enableIpCheck && baselinePublicIp != null && !ipChanged) {
    fail(
      'Public IP did not change after VPN connected (baseline: $baselinePublicIp)',
    );
  }
}
