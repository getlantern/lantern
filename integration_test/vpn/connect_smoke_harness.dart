import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/core/common/app_eum.dart';

import '../utils/widget_wait_utils.dart';

const _vpnStateKeyPrefixes = <String>['vpn.switch.', 'vpn.status.'];

const _observableStates = <VPNStatus>[
  VPNStatus.connected,
  VPNStatus.disconnected,
  VPNStatus.connecting,
  VPNStatus.disconnecting,
  VPNStatus.missingPermission,
  VPNStatus.error,
];

const _vpnStateLabels = <VPNStatus, String>{
  VPNStatus.connected: 'Connected',
  VPNStatus.disconnected: 'Disconnected',
  VPNStatus.connecting: 'Connecting',
  VPNStatus.disconnecting: 'Disconnecting',
  VPNStatus.missingPermission: 'MissingPermission',
  VPNStatus.error: 'Error',
};

const _stableStates = <VPNStatus>[
  VPNStatus.connected,
  VPNStatus.disconnected,
  VPNStatus.missingPermission,
  VPNStatus.error,
];

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

class _VpnStateFinders {
  VPNStatus? current() {
    for (final state in _observableStates) {
      for (final prefix in _vpnStateKeyPrefixes) {
        if (find.byKey(Key('$prefix${state.name}')).evaluate().isNotEmpty) {
          return state;
        }
      }
    }

    for (final entry in _vpnStateLabels.entries) {
      if (find.text(entry.value).evaluate().isNotEmpty) {
        return entry.key;
      }
    }

    return null;
  }

  Future<VPNStatus?> tryWaitFor(
    WidgetTester tester, {
    required List<VPNStatus> expected,
    required Duration timeout,
  }) async {
    final end = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 200));
      final state = current();
      if (expected.contains(state)) {
        return state;
      }
    }
    return null;
  }

  Future<VPNStatus> waitFor(
    WidgetTester tester, {
    required List<VPNStatus> expected,
    required Duration timeout,
    String? reason,
  }) async {
    final state = await tryWaitFor(
      tester,
      expected: expected,
      timeout: timeout,
    );
    if (state != null) {
      return state;
    }

    final debugKeys =
        tester.allWidgets
            .map((w) => w.key)
            .whereType<Key>()
            .map((k) => k.toString())
            .where((k) => k.contains('vpn.') || k.contains('onboarding.'))
            .toSet()
            .toList()
          ..sort();
    fail(
      '${reason ?? 'Timed out waiting for VPN state'}. Last observed: ${current()?.name ?? 'unknown'}. '
      'Visible keyed widgets: $debugKeys',
    );
  }
}

Future<void> _waitForVpnToggleWithOnboardingHandling(
  WidgetTester tester, {
  required Finder vpnToggle,
  required Finder onboardingScreen,
  required Finder onboardingSkip,
  required Finder onboardingPrimary,
  required Duration timeout,
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    if (onboardingScreen.evaluate().isNotEmpty) {
      if (onboardingSkip.evaluate().isNotEmpty) {
        await tester.tap(onboardingSkip);
      } else if (onboardingPrimary.evaluate().isNotEmpty) {
        await tester.tap(onboardingPrimary);
      }
      await tester.pump(const Duration(milliseconds: 400));
      continue;
    }

    if (vpnToggle.hitTestable().evaluate().isNotEmpty) {
      return;
    }

    await tester.pump(const Duration(milliseconds: 300));
  }
  fail('VPN toggle not visible');
}

Future<void> _disconnectVpn(
  WidgetTester tester, {
  required Finder vpnToggle,
  required _VpnStateFinders vpnStateFinders,
}) async {
  final currentState = vpnStateFinders.current();
  if (currentState != VPNStatus.connected &&
      currentState != VPNStatus.connecting) {
    return;
  }

  await WidgetWaitUtils.waitForFinder(
    tester,
    vpnToggle,
    timeout: const Duration(seconds: 15),
    reason: 'VPN toggle not available for disconnect',
  );
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
  final homeScreen = find.byKey(const Key('home.screen'));
  final onboardingScreen = find.byKey(const Key('onboarding.screen'));
  final onboardingSkip = find.byKey(const Key('onboarding.skip'));
  final onboardingPrimary = find.byKey(const Key('onboarding.primary'));
  final vpnToggle = find.byKey(const Key('vpn.toggle'));
  final vpnStateFinders = _VpnStateFinders();
  String? baselinePublicIp;

  await WidgetWaitUtils.waitForAnyFinder(
    tester,
    [homeScreen, onboardingScreen],
    timeout: const Duration(seconds: 90),
    reason: 'Home or onboarding did not appear after launch',
  );

  await WidgetWaitUtils.waitForFinder(
    tester,
    homeScreen,
    timeout: const Duration(seconds: 45),
    reason: 'Home screen did not load',
  );

  await _waitForVpnToggleWithOnboardingHandling(
    tester,
    vpnToggle: vpnToggle,
    onboardingScreen: onboardingScreen,
    onboardingSkip: onboardingSkip,
    onboardingPrimary: onboardingPrimary,
    timeout: const Duration(seconds: 30),
  );

  await WidgetWaitUtils.waitForFinderToDisappear(
    tester,
    onboardingScreen,
    timeout: const Duration(seconds: 20),
    reason: 'Onboarding screen remained visible',
  );

  await WidgetWaitUtils.waitForFinder(
    tester,
    homeScreen,
    timeout: const Duration(seconds: 20),
    reason: 'Home screen was not visible after onboarding flow',
  );

  await WidgetWaitUtils.waitForFinder(
    tester,
    vpnToggle,
    timeout: const Duration(seconds: 20),
    reason: 'VPN toggle was not visible on home screen',
  );

  var vpnState = await vpnStateFinders.tryWaitFor(
    tester,
    expected: _observableStates,
    timeout: const Duration(seconds: 20),
  );
  if (vpnState == null) {
    await _waitForVpnToggleWithOnboardingHandling(
      tester,
      vpnToggle: vpnToggle,
      onboardingScreen: onboardingScreen,
      onboardingSkip: onboardingSkip,
      onboardingPrimary: onboardingPrimary,
      timeout: const Duration(seconds: 15),
    );

    // Recover from startup race where UI state keys are briefly unavailable.
    await tester.tap(vpnToggle);
    await tester.pump(const Duration(milliseconds: 200));

    vpnState = await vpnStateFinders.waitFor(
      tester,
      expected: _observableStates,
      timeout: const Duration(seconds: 45),
      reason: 'Initial VPN state did not resolve after recovery toggle',
    );
  }

  if (vpnState == VPNStatus.connecting || vpnState == VPNStatus.disconnecting) {
    vpnState = await vpnStateFinders.waitFor(
      tester,
      expected: _stableStates,
      timeout: const Duration(seconds: 45),
      reason: 'VPN did not settle from transitional startup state',
    );
  }

  if (vpnState == VPNStatus.error) {
    fail('VPN reported error before connect/disconnect smoke');
  }
  if (vpnState == VPNStatus.missingPermission) {
    fail('VPN reported missing permission before connect/disconnect smoke');
  }

  if (vpnState == VPNStatus.connected) {
    await tester.tap(vpnToggle);
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

  bool ipChanged = true;
  try {
    await tester.tap(vpnToggle);
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
      vpnToggle: vpnToggle,
      vpnStateFinders: vpnStateFinders,
    );
  }

  if (enableIpCheck && baselinePublicIp != null && !ipChanged) {
    fail(
      'Public IP did not change after VPN connected (baseline: $baselinePublicIp)',
    );
  }
}
