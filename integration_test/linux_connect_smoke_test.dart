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
  none,
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

class _VpnStateFinders {
  _VpnStateFinders()
      : _byState = {
          _ObservedVpnState.connected:
              find.byKey(const Key('vpn.switch.connected')),
          _ObservedVpnState.disconnected:
              find.byKey(const Key('vpn.switch.disconnected')),
          _ObservedVpnState.connecting:
              find.byKey(const Key('vpn.switch.connecting')),
          _ObservedVpnState.disconnecting:
              find.byKey(const Key('vpn.switch.disconnecting')),
          _ObservedVpnState.missingPermission:
              find.byKey(const Key('vpn.switch.missingPermission')),
          _ObservedVpnState.error: find.byKey(const Key('vpn.switch.error')),
        };

  final Map<_ObservedVpnState, Finder> _byState;

  _ObservedVpnState current() {
    for (final entry in _byState.entries) {
      if (entry.value.evaluate().isNotEmpty) {
        return entry.key;
      }
    }
    return _ObservedVpnState.none;
  }

  Future<_ObservedVpnState> waitFor(
    WidgetTester tester, {
    required List<_ObservedVpnState> expected,
    required Duration timeout,
    String? reason,
  }) async {
    final end = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 200));
      final state = current();
      if (expected.contains(state)) {
        return state;
      }
    }
    fail(
        '${reason ?? 'Timed out waiting for VPN state'}. Last observed: ${current()}');
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
    final vpnStateFinders = _VpnStateFinders();

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

    var vpnState = await vpnStateFinders.waitFor(
      tester,
      expected: const [
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
      vpnState = await vpnStateFinders.waitFor(
        tester,
        expected: const [
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

      await vpnStateFinders.waitFor(
        tester,
        expected: const [_ObservedVpnState.disconnected],
        timeout: const Duration(seconds: 45),
        reason: 'Failed to reach disconnected state before connect test',
      );
    }

    await tester.tap(vpnToggle);
    await tester.pump(const Duration(milliseconds: 200));

    await vpnStateFinders.waitFor(
      tester,
      expected: const [_ObservedVpnState.connected],
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

    await vpnStateFinders.waitFor(
      tester,
      expected: const [_ObservedVpnState.disconnected],
      timeout: const Duration(seconds: 45),
      reason: 'VPN did not return to disconnected state within 45 seconds',
    );
  });
}
