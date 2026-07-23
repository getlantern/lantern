import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'widget_wait_utils.dart';

/// Drives the app shell during integration tests, independent of any feature.
/// Android-only for now; other platforms still use `vpn/vpn_smoke_helpers.dart`.
class AppRobot {
  AppRobot(this.tester);

  final WidgetTester tester;

  final Finder homeScreen = find.byKey(const Key('home.screen'));
  final Finder onboardingScreen = find.byKey(const Key('onboarding.screen'));
  final Finder onboardingSkip = find.byKey(const Key('onboarding.skip'));
  final Finder onboardingPrimary = find.byKey(const Key('onboarding.primary'));

  /// String-valued widget keys currently in the tree, sorted — a lightweight
  /// "what's on screen" dump for failure diagnostics. `Key('foo')` is a
  /// `ValueKey<String>`, so this captures the app's own keys and skips internal
  /// GlobalKeys.
  List<String> visibleKeys() {
    final keys = <String>{};
    for (final widget in tester.allWidgets) {
      final key = widget.key;
      if (key is ValueKey<String>) {
        keys.add(key.value);
      }
    }
    return keys.toList()..sort();
  }

  /// Waits for the home screen after launch. Does not touch onboarding.
  Future<void> launchToHome() async {
    await WidgetWaitUtils.waitForFinder(
      tester,
      homeScreen,
      timeout: const Duration(seconds: 90),
      reason: 'Home screen did not load',
    );
  }

  /// Dismisses onboarding if on screen: taps skip (falling back to primary),
  /// returns whether it was present. Waits for the button to be hit-testable
  /// first (it animates in offstage; tapping too early throws), then for the
  /// route to pop.
  Future<bool> dismissOnboardingIfShown() async {
    if (onboardingScreen.evaluate().isEmpty) {
      return false;
    }

    final skip = onboardingSkip.hitTestable();
    final primary = onboardingPrimary.hitTestable();

    final tapDeadline = DateTime.now().add(const Duration(seconds: 5));
    while (DateTime.now().isBefore(tapDeadline)) {
      if (onboardingScreen.evaluate().isEmpty) {
        return true;
      }
      final target = skip.evaluate().isNotEmpty
          ? skip
          : (primary.evaluate().isNotEmpty ? primary : null);
      if (target != null) {
        await tester.tap(target);
        await tester.pump(const Duration(milliseconds: 400));
        break;
      }
      await tester.pump(const Duration(milliseconds: 200));
    }

    // Let the pop settle so callers don't re-enter a half-dismissed route.
    await WidgetWaitUtils.waitForFinderToDisappear(
      tester,
      onboardingScreen,
      timeout: const Duration(seconds: 10),
      reason: 'Onboarding did not close after dismiss',
    );
    return true;
  }

  /// Waits until [control] is hit-testable — the app-ready gate — clearing
  /// onboarding that appears while waiting. Home renders before onboarding is
  /// pushed on top of it, so we first spend up to [onboardingGrace] letting
  /// onboarding appear and clearing it before trusting the control.
  Future<void> waitForControlReady(
    Finder control, {
    required String controlName,
    Duration onboardingGrace = const Duration(seconds: 8),
  }) async {
    final graceEnd = DateTime.now().add(onboardingGrace);
    while (DateTime.now().isBefore(graceEnd)) {
      if (onboardingScreen.evaluate().isNotEmpty) {
        await dismissOnboardingIfShown();
        break;
      }
      await tester.pump(const Duration(milliseconds: 200));
    }

    final end = DateTime.now().add(const Duration(seconds: 45));
    while (DateTime.now().isBefore(end)) {
      if (onboardingScreen.evaluate().isNotEmpty) {
        await dismissOnboardingIfShown();
        continue;
      }

      if (control.hitTestable().evaluate().isNotEmpty) {
        return;
      }

      await tester.pump(const Duration(milliseconds: 300));
    }
    fail('$controlName not visible');
  }
}
