import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/core/common/app_eum.dart';

import '../utils/app_robot.dart';
import '../utils/vpn_robot.dart';

/// Desktop connect/disconnect smoke harness. App shell via [AppRobot], VPN
/// state via [VpnRobot] (which listens to vpnProvider) — same structure as
/// the Android harness in android_connect_smoke_harness.dart.

const _ipCheckEndpoint = 'https://api64.ipify.org';
const _forceFullTunnelForSmoke = bool.fromEnvironment(
  'SMOKE_FORCE_FULL_TUNNEL',
  defaultValue: false,
);

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

Future<void> runConnectSmokeHarness(
  WidgetTester tester, {
  bool enableIpCheck = false,
  bool requireTrafficAfterConnect = false,
}) async {
  final app = AppRobot(tester);
  final vpn = VpnRobot(tester, app);

  try {
    await app.launchToHome();
    await app.waitForControlReady(vpn.vpnToggle, controlName: 'VPN toggle');
    await vpn.ensureDisconnected();
  } catch (_) {
    await app.captureScreenshot('connect-smoke-setup-failure');
    rethrow;
  }
  await app.captureScreenshot('connect-smoke-baseline');

  vpn.beginErrorWatch();
  addTearDown(vpn.assertNoErrorsSeen);

  if (_forceFullTunnelForSmoke) {
    debugPrint(
      'SMOKE_FORCE_FULL_TUNNEL enabled; switching to full tunnel mode',
    );
    await vpn.setRoutingMode(RoutingMode.full);
  }

  String? baselinePublicIp;
  if (enableIpCheck) {
    debugPrint('IP check: enabled; fetching baseline before connect');
    baselinePublicIp = await _fetchPublicIpWithRetry(
      timeout: const Duration(seconds: 40),
      reason: 'before connect',
    );
  }

  var ipChanged = true;
  try {
    await vpn.connect();
    await app.captureScreenshot('connect-smoke-connected');

    if (requireTrafficAfterConnect) {
      debugPrint('IP check: confirming public traffic after connect');
      await _fetchPublicIpWithRetry(
        timeout: const Duration(seconds: 45),
        reason: 'after connect',
      );
    }

    if (enableIpCheck && baselinePublicIp != null) {
      debugPrint('IP check: waiting for IP change after connect');
      await Future<void>.delayed(const Duration(seconds: 3));
      ipChanged = await _didPublicIpChangeFromBaseline(baselinePublicIp);
      if (ipChanged) {
        debugPrint('IP check: passed');
      }
    }
  } catch (_) {
    // Capture the failing screen before the disconnect cleanup changes it.
    await app.captureScreenshot('connect-smoke-failure');
    rethrow;
  } finally {
    await vpn.disconnectIfNeeded();
    await app.captureScreenshot('connect-smoke-disconnected');
  }

  if (enableIpCheck && baselinePublicIp != null && !ipChanged) {
    fail(
      'Public IP did not change after VPN connected (baseline: $baselinePublicIp)',
    );
  }
}
