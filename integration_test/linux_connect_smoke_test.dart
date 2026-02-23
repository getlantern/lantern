import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lantern/main.dart' as app;

enum _ObservedVpnState {
  connected,
  disconnected,
  connecting,
  disconnecting,
  error,
  none,
}

extension on _ObservedVpnState {
  String get suffix => switch (this) {
        _ObservedVpnState.connected => 'connected',
        _ObservedVpnState.disconnected => 'disconnected',
        _ObservedVpnState.connecting => 'connecting',
        _ObservedVpnState.disconnecting => 'disconnecting',
        _ObservedVpnState.error => 'error',
        _ObservedVpnState.none => 'none',
      };
}

const _vpnStateKeyPrefixes = <String>[
  'vpn.switch.',
  'vpn.status.',
];

const _vpnStateLabels = <_ObservedVpnState, String>{
  _ObservedVpnState.connected: 'Connected',
  _ObservedVpnState.disconnected: 'Disconnected',
  _ObservedVpnState.connecting: 'Connecting',
  _ObservedVpnState.disconnecting: 'Disconnecting',
  _ObservedVpnState.error: 'Error',
};

const _initialStates = <_ObservedVpnState>[
  _ObservedVpnState.connected,
  _ObservedVpnState.disconnected,
  _ObservedVpnState.connecting,
  _ObservedVpnState.disconnecting,
  _ObservedVpnState.error,
];

const _stableStates = <_ObservedVpnState>[
  _ObservedVpnState.connected,
  _ObservedVpnState.disconnected,
  _ObservedVpnState.error,
];

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

Future<void> _waitForFinderToDisappear(
  WidgetTester tester,
  Finder finder, {
  required Duration timeout,
  String? reason,
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (finder.evaluate().isEmpty) {
      return;
    }
  }
  fail(reason ?? 'Timed out waiting for widget to disappear');
}

class _VpnStateFinders {
  _ObservedVpnState current() {
    for (final state in _ObservedVpnState.values) {
      if (state == _ObservedVpnState.none) {
        continue;
      }
      for (final prefix in _vpnStateKeyPrefixes) {
        if (find.byKey(Key('$prefix${state.suffix}')).evaluate().isNotEmpty) {
          return state;
        }
      }
    }

    for (final entry in _vpnStateLabels.entries) {
      if (find.text(entry.value).evaluate().isNotEmpty) {
        return entry.key;
      }
    }

    return _ObservedVpnState.none;
  }

  Future<_ObservedVpnState> tryWaitFor(
    WidgetTester tester, {
    required List<_ObservedVpnState> expected,
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
    return _ObservedVpnState.none;
  }

  Future<_ObservedVpnState> waitFor(
    WidgetTester tester, {
    required List<_ObservedVpnState> expected,
    required Duration timeout,
    String? reason,
  }) async {
    final state = await tryWaitFor(
      tester,
      expected: expected,
      timeout: timeout,
    );
    if (state != _ObservedVpnState.none) {
      return state;
    }

    final debugKeys = tester.allWidgets
        .map((w) => w.key)
        .whereType<Key>()
        .map((k) => k.toString())
        .where((k) => k.contains('vpn.') || k.contains('onboarding.'))
        .toSet()
        .toList()
      ..sort();
    fail(
      '${reason ?? 'Timed out waiting for VPN state'}. Last observed: ${current()}. '
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

    await _waitForFinder(
      tester,
      homeScreen,
      timeout: const Duration(seconds: 20),
      reason: 'Home screen was not visible after onboarding flow',
    );

    await _waitForFinderToDisappear(
      tester,
      onboardingScreen,
      timeout: const Duration(seconds: 20),
      reason: 'Onboarding screen remained visible',
    );

    await _waitForFinder(
      tester,
      vpnToggle,
      timeout: const Duration(seconds: 20),
      reason: 'VPN toggle was not visible on home screen',
    );

    var vpnState = await vpnStateFinders.tryWaitFor(
      tester,
      expected: _initialStates,
      timeout: const Duration(seconds: 20),
    );
    if (vpnState == _ObservedVpnState.none) {
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
        expected: _initialStates,
        timeout: const Duration(seconds: 45),
        reason: 'Initial VPN state did not resolve after recovery toggle',
      );
    }

    if (vpnState == _ObservedVpnState.connecting ||
        vpnState == _ObservedVpnState.disconnecting) {
      vpnState = await vpnStateFinders.waitFor(
        tester,
        expected: _stableStates,
        timeout: const Duration(seconds: 45),
        reason: 'VPN did not settle from transitional startup state',
      );
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
