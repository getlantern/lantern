import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lantern/main.dart' as app;

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

    final disconnectedStatus = find.byKey(const Key('vpn.status.disconnected'));
    final connectedStatus = find.byKey(const Key('vpn.status.connected'));

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

    await _waitForAnyFinder(
      tester,
      [connectedStatus, disconnectedStatus],
      timeout: const Duration(seconds: 30),
      reason: 'Initial VPN status did not resolve',
    );

    if (connectedStatus.evaluate().isNotEmpty) {
      await tester.tap(vpnToggle);
      await tester.pump(const Duration(milliseconds: 200));
      await _waitForFinder(
        tester,
        disconnectedStatus,
        timeout: const Duration(seconds: 30),
        reason: 'Failed to reach disconnected state before connect test',
      );
    }

    await tester.tap(vpnToggle);
    await tester.pump(const Duration(milliseconds: 200));

    await _waitForFinder(
      tester,
      connectedStatus,
      timeout: const Duration(seconds: 30),
      reason: 'VPN did not reach connected state within 30 seconds',
    );

    await _waitForFinder(
      tester,
      vpnToggle,
      timeout: const Duration(seconds: 15),
      reason: 'VPN toggle not available for disconnect',
    );
    await tester.tap(vpnToggle);
    await tester.pump(const Duration(milliseconds: 200));

    await _waitForFinder(
      tester,
      disconnectedStatus,
      timeout: const Duration(seconds: 30),
      reason: 'VPN did not return to disconnected state within 30 seconds',
    );
  });
}
