import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lantern/main.dart' as app;

enum _ObservedVpnState {
  connected,
  disconnected,
  connecting,
  disconnecting,
  missingPermission,
  error,
  unknown,
}

Future<void> _waitForFinder(
  WidgetTester tester,
  Finder finder, {
  required Duration timeout,
  String? reason,
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (finder.evaluate().isNotEmpty) {
      return;
    }
  }
  fail(reason ?? 'Timed out waiting for expected widget');
}

Future<void> _waitForAnyFinder(
  WidgetTester tester,
  List<Finder> finders, {
  required Duration timeout,
  String? reason,
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 200));
    for (final finder in finders) {
      if (finder.evaluate().isNotEmpty) {
        return;
      }
    }
  }
  fail(reason ?? 'Timed out waiting for any expected widget');
}

_ObservedVpnState _currentVpnState({
  required Finder switchConnected,
  required Finder switchDisconnected,
  required Finder switchConnecting,
  required Finder switchDisconnecting,
  required Finder switchMissingPermission,
  required Finder switchError,
}) {
  if (switchConnected.evaluate().isNotEmpty) {
    return _ObservedVpnState.connected;
  }
  if (switchDisconnected.evaluate().isNotEmpty) {
    return _ObservedVpnState.disconnected;
  }
  if (switchConnecting.evaluate().isNotEmpty) {
    return _ObservedVpnState.connecting;
  }
  if (switchDisconnecting.evaluate().isNotEmpty) {
    return _ObservedVpnState.disconnecting;
  }
  if (switchMissingPermission.evaluate().isNotEmpty) {
    return _ObservedVpnState.missingPermission;
  }
  if (switchError.evaluate().isNotEmpty) {
    return _ObservedVpnState.error;
  }
  return _ObservedVpnState.unknown;
}

Future<_ObservedVpnState> _waitForVpnState(
  WidgetTester tester, {
  required Finder switchConnected,
  required Finder switchDisconnected,
  required Finder switchConnecting,
  required Finder switchDisconnecting,
  required Finder switchMissingPermission,
  required Finder switchError,
  required List<_ObservedVpnState> expectedStates,
  required Duration timeout,
  String? reason,
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 200));
    final state = _currentVpnState(
      switchConnected: switchConnected,
      switchDisconnected: switchDisconnected,
      switchConnecting: switchConnecting,
      switchDisconnecting: switchDisconnecting,
      switchMissingPermission: switchMissingPermission,
      switchError: switchError,
    );
    if (expectedStates.contains(state)) {
      return state;
    }
  }

  final lastState = _currentVpnState(
    switchConnected: switchConnected,
    switchDisconnected: switchDisconnected,
    switchConnecting: switchConnecting,
    switchDisconnecting: switchDisconnecting,
    switchMissingPermission: switchMissingPermission,
    switchError: switchError,
  );
  fail(
      '${reason ?? 'Timed out waiting for VPN state'}. Last observed: $lastState');
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
    if (vpnToggle.evaluate().isNotEmpty) {
      return;
    }

    if (onboardingScreen.evaluate().isNotEmpty) {
      if (onboardingSkip.evaluate().isNotEmpty) {
        await tester.tap(onboardingSkip);
      } else if (onboardingPrimary.evaluate().isNotEmpty) {
        await tester.tap(onboardingPrimary);
      }
    }

    await tester.pump(const Duration(milliseconds: 300));
  }
  fail('VPN toggle not visible');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Linux VPN connect/disconnect smoke', (tester) async {
    app.main();

    final homeScreen = find.byKey(const Key('home.screen'));
    final onboardingScreen = find.byKey(const Key('onboarding.screen'));
    final onboardingSkip = find.byKey(const Key('onboarding.skip'));
    final onboardingPrimary = find.byKey(const Key('onboarding.primary'));
    final vpnToggle = find.byKey(const Key('vpn.toggle'));

    final switchConnected = find.byKey(const Key('vpn.switch.connected'));
    final switchDisconnected = find.byKey(const Key('vpn.switch.disconnected'));
    final switchConnecting = find.byKey(const Key('vpn.switch.connecting'));
    final switchDisconnecting =
        find.byKey(const Key('vpn.switch.disconnecting'));
    final switchMissingPermission =
        find.byKey(const Key('vpn.switch.missingPermission'));
    final switchError = find.byKey(const Key('vpn.switch.error'));

    await _waitForAnyFinder(
      tester,
      [homeScreen, onboardingScreen],
      timeout: const Duration(seconds: 90),
      reason: 'Home or onboarding did not appear after launch',
    );

    await _waitForFinder(
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

    var vpnState = await _waitForVpnState(
      tester,
      switchConnected: switchConnected,
      switchDisconnected: switchDisconnected,
      switchConnecting: switchConnecting,
      switchDisconnecting: switchDisconnecting,
      switchMissingPermission: switchMissingPermission,
      switchError: switchError,
      expectedStates: const [
        _ObservedVpnState.connected,
        _ObservedVpnState.disconnected,
        _ObservedVpnState.connecting,
        _ObservedVpnState.disconnecting,
        _ObservedVpnState.missingPermission,
        _ObservedVpnState.error,
      ],
      timeout: const Duration(seconds: 45),
      reason: 'Initial VPN state did not resolve',
    );

    if (vpnState == _ObservedVpnState.connecting ||
        vpnState == _ObservedVpnState.disconnecting) {
      vpnState = await _waitForVpnState(
        tester,
        switchConnected: switchConnected,
        switchDisconnected: switchDisconnected,
        switchConnecting: switchConnecting,
        switchDisconnecting: switchDisconnecting,
        switchMissingPermission: switchMissingPermission,
        switchError: switchError,
        expectedStates: const [
          _ObservedVpnState.connected,
          _ObservedVpnState.disconnected,
          _ObservedVpnState.missingPermission,
          _ObservedVpnState.error,
        ],
        timeout: const Duration(seconds: 45),
        reason: 'VPN did not settle from transitional startup state',
      );
    }

    if (vpnState == _ObservedVpnState.missingPermission) {
      fail('VPN reported missingPermission before connect/disconnect smoke');
    }
    if (vpnState == _ObservedVpnState.error) {
      fail('VPN reported error before connect/disconnect smoke');
    }

    if (vpnState == _ObservedVpnState.connected) {
      await tester.tap(vpnToggle);
      await tester.pump(const Duration(milliseconds: 200));

      await _waitForVpnState(
        tester,
        switchConnected: switchConnected,
        switchDisconnected: switchDisconnected,
        switchConnecting: switchConnecting,
        switchDisconnecting: switchDisconnecting,
        switchMissingPermission: switchMissingPermission,
        switchError: switchError,
        expectedStates: const [_ObservedVpnState.disconnected],
        timeout: const Duration(seconds: 45),
        reason: 'Failed to reach disconnected state before connect test',
      );
    }

    await tester.tap(vpnToggle);
    await tester.pump(const Duration(milliseconds: 200));

    await _waitForVpnState(
      tester,
      switchConnected: switchConnected,
      switchDisconnected: switchDisconnected,
      switchConnecting: switchConnecting,
      switchDisconnecting: switchDisconnecting,
      switchMissingPermission: switchMissingPermission,
      switchError: switchError,
      expectedStates: const [_ObservedVpnState.connected],
      timeout: const Duration(seconds: 45),
      reason: 'VPN did not reach connected state within 45 seconds',
    );

    await _waitForFinder(
      tester,
      vpnToggle,
      timeout: const Duration(seconds: 15),
      reason: 'VPN toggle not available for disconnect',
    );
    await tester.tap(vpnToggle);
    await tester.pump(const Duration(milliseconds: 200));

    await _waitForVpnState(
      tester,
      switchConnected: switchConnected,
      switchDisconnected: switchDisconnected,
      switchConnecting: switchConnecting,
      switchDisconnecting: switchDisconnecting,
      switchMissingPermission: switchMissingPermission,
      switchError: switchError,
      expectedStates: const [_ObservedVpnState.disconnected],
      timeout: const Duration(seconds: 45),
      reason: 'VPN did not return to disconnected state within 45 seconds',
    );
  });
}
