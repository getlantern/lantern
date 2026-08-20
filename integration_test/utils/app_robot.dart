import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/core/common/common.dart' show appRouter;
import 'package:lantern/core/utils/storage_utils.dart';

import 'widget_wait_utils.dart';

/// Test log line, prefixed so it's easy to grep out of the device logcat
/// that Firebase Test Lab captures (adb logcat | grep E2E).
void e2eLog(String message) => debugPrint('[E2E] $message');

/// Drives the app shell during Android and desktop integration tests,
/// independent of any feature.
class AppRobot {
  AppRobot(this.tester);

  final WidgetTester tester;

  final Finder homeScreen = find.byKey(const Key('home.screen'));
  final Finder onboardingScreen = find.byKey(const Key('onboarding.screen'));
  final Finder onboardingSkip = find.byKey(const Key('onboarding.skip'));
  final Finder onboardingPrimary = find.byKey(const Key('onboarding.primary'));
  final Finder macosExtensionScreen = find.byKey(
    const Key('macos_extension.screen'),
  );

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

  /// Captures the current Flutter surface without failing the smoke when the
  /// platform does not expose a capturable root layer.
  Future<void> captureScreenshot(String name) async {
    try {
      final renderView = tester.binding.renderViews.first;
      final layer = renderView.debugLayer;
      if (layer is! OffsetLayer) {
        e2eLog('Screenshot $name skipped: root layer is not capturable');
        return;
      }
      final image = await layer.toImage(renderView.paintBounds);
      try {
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        if (data == null) {
          e2eLog('Screenshot $name skipped: no image data');
          return;
        }
        final directory = Directory(
          '${await AppStorageUtils.getAppLogDirectory()}/screenshots',
        );
        await directory.create(recursive: true);
        final file = File('${directory.path}/$name.png');
        await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
        e2eLog('Screenshot saved: ${file.path}');
      } finally {
        image.dispose();
      }
    } catch (error) {
      e2eLog('Screenshot $name failed: $error');
    }
  }

  /// Waits until home is usable. Onboarding is pushed on top shortly after
  /// home renders, so gate on the menu button via [waitForControlReady],
  /// which waits out that window and clears onboarding.
  Future<void> waitForHomeReady() async {
    e2eLog('Waiting for home to be ready');
    await launchToHome();
    await waitForControlReady(
      find.byKey(const Key('home.menu_button')),
      controlName: 'Home menu button',
    );
    e2eLog('Home ready');
  }

  /// Opens Settings through the UI: home menu button.
  Future<void> openSettings() async {
    await waitForHomeReady();
    await tap(
      find.byKey(const Key('home.menu_button')),
      name: 'Home menu button',
    );
  }

  /// Opens the Language screen through the UI: Settings -> Language.
  Future<void> openLanguage() async {
    await openSettings();
    await tap(
      find.byKey(const Key('setting.language_tile')),
      name: 'Settings language tile',
    );
    await WidgetWaitUtils.waitForFinder(
      tester,
      find.byKey(const Key('language.list')),
      timeout: const Duration(seconds: 15),
      reason: 'Language screen did not open',
    );
  }

  /// Opens Appearance through the UI: Settings -> Appearance. Shows as a
  /// bottom sheet on mobile and a pushed screen on desktop; both render the
  /// same list.
  Future<void> openAppearance() async {
    await openSettings();
    await tap(
      find.byKey(const Key('setting.appearance_tile')),
      name: 'Settings appearance tile',
    );
    await WidgetWaitUtils.waitForFinder(
      tester,
      find.byKey(const Key('appearance.list')),
      timeout: const Duration(seconds: 15),
      reason: 'Appearance options did not open',
    );
  }

  /// Opens Plans through the UI: Settings -> Upgrade to Pro. Returns false
  /// when the account is already Pro (no upgrade button), so callers can
  /// soft-skip. Waits past the loading state until real plan data renders.
  Future<bool> openPlansIfFree() async {
    await openSettings();
    final upgrade = find.byKey(const Key('setting.upgrade_pro_button'));
    if (upgrade.evaluate().isEmpty) {
      e2eLog('No upgrade button on Settings — account is Pro');
      return false;
    }
    await tap(upgrade, name: 'Upgrade to Pro button');
    await WidgetWaitUtils.waitForFinder(
      tester,
      find.byKey(const Key('plans.list')),
      timeout: const Duration(seconds: 45),
      reason: 'Plans did not load (still loading, or fetch error state)',
    );
    e2eLog('Plans loaded');
    return true;
  }

  /// Opens ReportIssue through the UI:
  /// home menu -> Settings -> Support -> Report an issue.
  Future<void> openReportIssue() async {
    await openSettings();
    await tap(
      find.byKey(const Key('setting.support_tile')),
      name: 'Settings support tile',
    );
    await tap(
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

  /// Dismisses the soft keyboard if open. Navigating with the keyboard up
  /// shrinks the viewport and overflows tight layouts on small devices
  /// (e.g. home's Column, home.dart:165), which the framework treats as a
  /// test failure.
  /// The IME hide animation is platform-driven, so pumpAndSettle alone can
  /// return while the keyboard is still animating away (seen on API 33);
  /// poll the window inset until it actually reaches zero.
  Future<void> hideKeyboard() async {
    FocusManager.instance.primaryFocus?.unfocus();
    await SystemChannels.textInput.invokeMethod('TextInput.hide');
    await tester.pumpAndSettle();

    final end = DateTime.now().add(const Duration(seconds: 5));
    while (DateTime.now().isBefore(end)) {
      if (tester.view.viewInsets.bottom == 0) {
        return;
      }
      await tester.pump(const Duration(milliseconds: 100));
    }
    e2eLog('Keyboard inset still ${tester.view.viewInsets.bottom} after 5s');
  }

  /// Pops every route back to the root (home). Hides the keyboard first —
  /// see [hideKeyboard]. The standard cleanup at the end of a test.
  Future<void> resetToRoot() async {
    e2eLog('Resetting navigation to root');
    await hideKeyboard();
    appRouter.popUntilRoot();
    await tester.pumpAndSettle();
  }

  /// Waits until any of [finders] appears; fails naming what never showed up.
  Future<void> waitForAny(
    Map<String, Finder> finders, {
    Duration timeout = const Duration(seconds: 20),
  }) => WidgetWaitUtils.waitForAnyFinder(
    tester,
    finders.values.toList(),
    timeout: timeout,
    reason: 'None of ${finders.keys.join(', ')} appeared within $timeout',
  );

  /// Waits for [target] and taps it. Native handoffs can skip settling.
  Future<void> tap(
    Finder target, {
    required String name,
    bool settle = true,
  }) async {
    e2eLog('Tapping $name');
    await WidgetWaitUtils.waitForFinder(
      tester,
      target,
      timeout: const Duration(seconds: 15),
      reason: '$name not visible',
    );
    await tester.ensureVisible(target);
    await tester.tap(target);
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump(const Duration(milliseconds: 300));
    }
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
    e2eLog('Onboarding shown — dismissing');

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
    e2eLog('Onboarding dismissed');
    return true;
  }

  /// Dismisses the macOS system-extension screen when it covers home. Payment
  /// smokes do not exercise the VPN, so they can safely close this prompt.
  Future<bool> dismissMacOSExtensionScreenIfShown() async {
    if (macosExtensionScreen.evaluate().isEmpty) {
      return false;
    }
    e2eLog('macOS system extension screen shown — dismissing');

    final close = find
        .descendant(
          of: macosExtensionScreen,
          matching: find.byType(CloseButton),
        )
        .hitTestable();
    final tapDeadline = DateTime.now().add(const Duration(seconds: 5));
    while (DateTime.now().isBefore(tapDeadline)) {
      if (macosExtensionScreen.evaluate().isEmpty) return true;
      if (close.evaluate().isNotEmpty) {
        await tester.tap(close);
        await tester.pump(const Duration(milliseconds: 400));
        break;
      }
      await tester.pump(const Duration(milliseconds: 200));
    }

    await WidgetWaitUtils.waitForFinderToDisappear(
      tester,
      macosExtensionScreen,
      timeout: const Duration(seconds: 10),
      reason: 'macOS system extension screen did not close after dismiss',
    );
    e2eLog('macOS system extension screen dismissed');
    return true;
  }

  /// Waits until [control] is hit-testable — the app-ready gate — clearing
  /// onboarding that appears while waiting. Home renders before onboarding is
  /// pushed on top of it, so we first spend up to [onboardingGrace] letting
  /// onboarding appear and clearing it before trusting the control.
  Future<void> waitForControlReady(
    Finder control, {
    required String controlName,
    Duration onboardingGrace = const Duration(seconds: 4),
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
      if (macosExtensionScreen.evaluate().isNotEmpty) {
        await dismissMacOSExtensionScreenIfShown();
        continue;
      }

      if (control.hitTestable().evaluate().isNotEmpty) {
        return;
      }

      await tester.pump(const Duration(milliseconds: 300));
    }
    // Dump what IS on screen so a remote-run failure is diagnosable.
    fail('$controlName not visible. Visible keys: ${visibleKeys().join(', ')}');
  }
}
