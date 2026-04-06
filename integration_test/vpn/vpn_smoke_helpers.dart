import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/core/common/app_eum.dart';

import '../utils/widget_wait_utils.dart';

const vpnStateKeyPrefixes = <String>['vpn.switch.', 'vpn.status.'];

const observableVpnStates = <VPNStatus>[
  VPNStatus.connected,
  VPNStatus.disconnected,
  VPNStatus.connecting,
  VPNStatus.disconnecting,
  VPNStatus.missingPermission,
  VPNStatus.error,
];

const stableVpnStates = <VPNStatus>[
  VPNStatus.connected,
  VPNStatus.disconnected,
  VPNStatus.missingPermission,
  VPNStatus.error,
];

class VpnSmokeFinders {
  final Finder homeScreen = find.byKey(const Key('home.screen'));
  final Finder onboardingScreen = find.byKey(const Key('onboarding.screen'));
  final Finder onboardingSkip = find.byKey(const Key('onboarding.skip'));
  final Finder onboardingPrimary = find.byKey(const Key('onboarding.primary'));
  final Finder vpnToggle = find.byKey(const Key('vpn.toggle'));
}

class VpnStateFinders {
  final Map<VPNStatus, String> _textLabels;

  VpnStateFinders({Map<VPNStatus, String> textLabels = const {}})
    : _textLabels = textLabels;

  VPNStatus? current() {
    for (final state in observableVpnStates) {
      for (final prefix in vpnStateKeyPrefixes) {
        if (find.byKey(Key('$prefix${state.name}')).evaluate().isNotEmpty) {
          return state;
        }
      }
    }

    for (final entry in _textLabels.entries) {
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
    required String reason,
  }) async {
    final state = await tryWaitFor(
      tester,
      expected: expected,
      timeout: timeout,
    );
    if (state != null) {
      return state;
    }
    fail('$reason. ${buildVpnDebugSnapshot(tester, this)}');
  }
}

String buildVpnDebugSnapshot(
  WidgetTester tester,
  VpnStateFinders vpnStateFinders,
) {
  final debugKeys = collectVisibleSmokeDebugKeys(tester);
  return 'Last observed VPN state: ${vpnStateFinders.current()?.name ?? 'unknown'}. '
      'Visible keyed widgets: $debugKeys';
}

Never failWithVpnDebugSnapshot(
  String message,
  WidgetTester tester,
  VpnStateFinders vpnStateFinders,
) {
  fail('$message. ${buildVpnDebugSnapshot(tester, vpnStateFinders)}');
}

List<String> collectVisibleSmokeDebugKeys(WidgetTester tester) {
  return tester.allWidgets
      .map((w) => w.key)
      .whereType<Key>()
      .map((k) => k.toString())
      .where(
        (k) =>
            k.contains('vpn.') ||
            k.contains('onboarding.') ||
            k.contains('server_selection.') ||
            k.contains('join_private_server.'),
      )
      .toSet()
      .toList()
    ..sort();
}

Future<void> waitForVpnToggleWithOnboardingHandling(
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

Future<void> waitForHomeReadyForVpnSmoke(
  WidgetTester tester, {
  required VpnSmokeFinders finders,
}) async {
  await WidgetWaitUtils.waitForAnyFinder(
    tester,
    [finders.homeScreen, finders.onboardingScreen],
    timeout: const Duration(seconds: 90),
    reason: 'Home or onboarding did not appear after launch',
  );

  await WidgetWaitUtils.waitForFinder(
    tester,
    finders.homeScreen,
    timeout: const Duration(seconds: 45),
    reason: 'Home screen did not load',
  );

  await waitForVpnToggleWithOnboardingHandling(
    tester,
    vpnToggle: finders.vpnToggle,
    onboardingScreen: finders.onboardingScreen,
    onboardingSkip: finders.onboardingSkip,
    onboardingPrimary: finders.onboardingPrimary,
    timeout: const Duration(seconds: 30),
  );

  await WidgetWaitUtils.waitForFinderToDisappear(
    tester,
    finders.onboardingScreen,
    timeout: const Duration(seconds: 20),
    reason: 'Onboarding screen remained visible',
  );

  await WidgetWaitUtils.waitForFinder(
    tester,
    finders.homeScreen,
    timeout: const Duration(seconds: 20),
    reason: 'Home screen was not visible after onboarding flow',
  );

  await WidgetWaitUtils.waitForFinder(
    tester,
    finders.vpnToggle,
    timeout: const Duration(seconds: 20),
    reason: 'VPN toggle was not visible on home screen',
  );
}

Future<VPNStatus> resolveInitialStableVpnStateForSmoke(
  WidgetTester tester, {
  required VpnSmokeFinders finders,
  required VpnStateFinders vpnStateFinders,
}) async {
  var vpnState = await vpnStateFinders.tryWaitFor(
    tester,
    expected: observableVpnStates,
    timeout: const Duration(seconds: 20),
  );

  if (vpnState == null) {
    await waitForVpnToggleWithOnboardingHandling(
      tester,
      vpnToggle: finders.vpnToggle,
      onboardingScreen: finders.onboardingScreen,
      onboardingSkip: finders.onboardingSkip,
      onboardingPrimary: finders.onboardingPrimary,
      timeout: const Duration(seconds: 15),
    );

    // Recover from startup race where VPN state keys are briefly unavailable.
    await tester.tap(finders.vpnToggle);
    await tester.pump(const Duration(milliseconds: 200));

    vpnState = await vpnStateFinders.waitFor(
      tester,
      expected: observableVpnStates,
      timeout: const Duration(seconds: 45),
      reason: 'Initial VPN state did not resolve after recovery toggle',
    );
  }

  if (vpnState == VPNStatus.connecting || vpnState == VPNStatus.disconnecting) {
    vpnState = await vpnStateFinders.waitFor(
      tester,
      expected: stableVpnStates,
      timeout: const Duration(seconds: 45),
      reason: 'VPN did not settle from transitional startup state',
    );
  }

  return vpnState;
}

Future<void> prepareVpnStartsDisconnectedForSmoke(
  WidgetTester tester, {
  required VpnSmokeFinders finders,
  required VpnStateFinders vpnStateFinders,
  required String scenario,
  Future<void> Function()? disconnectFromConnectedState,
}) async {
  await waitForHomeReadyForVpnSmoke(tester, finders: finders);

  var vpnState = await resolveInitialStableVpnStateForSmoke(
    tester,
    finders: finders,
    vpnStateFinders: vpnStateFinders,
  );

  if (vpnState == VPNStatus.error) {
    failWithVpnDebugSnapshot(
      'VPN reported error before $scenario',
      tester,
      vpnStateFinders,
    );
  }
  if (vpnState == VPNStatus.missingPermission) {
    failWithVpnDebugSnapshot(
      'VPN reported missing permission before $scenario',
      tester,
      vpnStateFinders,
    );
  }

  if (vpnState == VPNStatus.connected) {
    if (disconnectFromConnectedState != null) {
      await disconnectFromConnectedState();
    } else {
      await tester.tap(finders.vpnToggle);
      await tester.pump(const Duration(milliseconds: 200));
    }

    vpnState = await vpnStateFinders.waitFor(
      tester,
      expected: const [VPNStatus.disconnected],
      timeout: const Duration(seconds: 45),
      reason: 'VPN did not reach disconnected state before $scenario',
    );
  }

  if (vpnState != VPNStatus.disconnected) {
    failWithVpnDebugSnapshot(
      'Expected disconnected state before $scenario, got ${vpnState.name}',
      tester,
      vpnStateFinders,
    );
  }
}
