import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/core/common/common.dart' show appRouter;
import 'package:lantern/main.dart' as app;

import 'widget_wait_utils.dart';

bool _appLaunched = false;

/// Launches the real app exactly once per test process. All scenarios in a
/// suite (and across suites in an aggregator run) share one app process, so
/// calling `app.main()` per test would re-register GetIt singletons and throw
/// ("Type X is already registered inside GetIt"). Later calls are no-ops.
Future<void> ensureAppLaunched() async {
  if (_appLaunched) {
    return;
  }
  _appLaunched = true;
  await app.main();
}

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

  /// Waits until the app is idle on the home screen and actually usable.
  /// Home renders first and onboarding is pushed on top a moment later, so
  /// checking for onboarding right after home appears misses it; instead this
  /// leans on [waitForControlReady], which waits out that window and clears
  /// onboarding before trusting the screen. Gates on the home menu button —
  /// it sits on the home app bar and is the first thing navigation taps.
  Future<void> waitForHomeReady() async {
    await launchToHome();
    await waitForControlReady(
      find.byKey(const Key('home.menu_button')),
      controlName: 'Home menu button',
    );
  }

  /// Navigates to the ReportIssue screen the way a user does: home app bar
  /// menu -> Settings -> Support -> Report an issue. Navigation only —
  /// on-screen interactions belong to the test (or a future feature robot).
  Future<void> openReportIssue() async {
    await waitForHomeReady();

    await _tap(
      find.byKey(const Key('home.menu_button')),
      name: 'Home menu button',
    );
    await _tap(
      find.byKey(const Key('setting.support_tile')),
      name: 'Settings support tile',
    );
    await _tap(
      find.byKey(const Key('support.report_issue_tile')),
      name: 'Support report-issue tile',
    );

    await WidgetWaitUtils.waitForFinder(
      tester,
      find.byKey(const Key('report_issue.description')),
      timeout: const Duration(seconds: 15),
      reason: 'Report issue screen did not open',
    );
  }

  /// Navigates one screen back, as the app bar back button would.
  Future<void> goBack() async {
    await appRouter.maybePop();
    await tester.pumpAndSettle();
  }

  /// Waits for [target] to be visible, then taps it and lets the resulting
  /// navigation settle.
  Future<void> _tap(Finder target, {required String name}) async {
    await WidgetWaitUtils.waitForFinder(
      tester,
      target,
      timeout: const Duration(seconds: 15),
      reason: '$name not visible',
    );
    await tester.ensureVisible(target);
    await tester.tap(target);
    await tester.pumpAndSettle();
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
