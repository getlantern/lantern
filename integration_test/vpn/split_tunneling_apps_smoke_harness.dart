import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/core/common/app_eum.dart';
import 'package:lantern/core/common/common.dart' show appRouter;
import 'package:lantern/core/widgets/custom_app_bar.dart' as lantern_widgets;

import '../utils/widget_wait_utils.dart';
import 'vpn_smoke_helpers.dart';

const _vpnStateLabels = <VPNStatus, String>{
  VPNStatus.connected: 'Connected',
  VPNStatus.disconnected: 'Disconnected',
  VPNStatus.connecting: 'Connecting',
  VPNStatus.disconnecting: 'Disconnecting',
  VPNStatus.missingPermission: 'MissingPermission',
  VPNStatus.error: 'Error',
};

String _keyToken(String value) {
  final token = value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
  if (token.isEmpty) {
    return 'unknown';
  }
  return token;
}

Future<void> _tapFinder(
  WidgetTester tester,
  Finder finder, {
  required Duration timeout,
  required String reason,
}) async {
  await WidgetWaitUtils.waitForFinder(
    tester,
    finder,
    timeout: timeout,
    reason: reason,
  );
  await tester.ensureVisible(finder.first);
  await tester.pump(const Duration(milliseconds: 150));

  final target = finder.hitTestable();
  if (target.evaluate().isEmpty) {
    fail(
      '$reason: widget was present but not tappable. '
      'Visible keyed widgets: ${collectVisibleSmokeDebugKeys(tester)}',
    );
  }

  await tester.tap(target.first);
  await tester.pump(const Duration(milliseconds: 250));
}

Future<bool> _tryGoBack(WidgetTester tester) async {
  final customBack = find.byType(lantern_widgets.BackButton).hitTestable();
  if (customBack.evaluate().isNotEmpty) {
    await tester.tap(customBack.first);
    await tester.pump(const Duration(milliseconds: 250));
    return true;
  }

  final materialBack = find.byType(BackButton).hitTestable();
  if (materialBack.evaluate().isNotEmpty) {
    await tester.tap(materialBack.first);
    await tester.pump(const Duration(milliseconds: 250));
    return true;
  }

  final poppedWithRouter = await appRouter.maybePop();
  if (poppedWithRouter) {
    await tester.pump(const Duration(milliseconds: 250));
    return true;
  }

  try {
    await tester.pageBack();
    await tester.pump(const Duration(milliseconds: 250));
    return true;
  } catch (_) {
    return false;
  }
}

Future<void> _returnToHome(
  WidgetTester tester, {
  required Finder homeScreen,
  required Finder vpnToggle,
}) async {
  if (homeScreen.evaluate().isNotEmpty ||
      vpnToggle.hitTestable().evaluate().isNotEmpty) {
    return;
  }

  final end = DateTime.now().add(const Duration(seconds: 25));
  while (DateTime.now().isBefore(end)) {
    if (homeScreen.evaluate().isNotEmpty ||
        vpnToggle.hitTestable().evaluate().isNotEmpty) {
      return;
    }

    if (await _tryGoBack(tester)) {
      continue;
    }

    await tester.pump(const Duration(milliseconds: 250));
  }

  appRouter.popUntilRoot();
  await tester.pump(const Duration(milliseconds: 400));
  if (homeScreen.evaluate().isNotEmpty ||
      vpnToggle.hitTestable().evaluate().isNotEmpty) {
    return;
  }

  fail(
    'Failed to return to home screen. '
    'Visible keyed widgets: ${collectVisibleSmokeDebugKeys(tester)}',
  );
}

Future<String> _waitForAppLocation({
  required WidgetTester tester,
  required Finder enabledListFinder,
  required Finder installedListFinder,
  required Finder appNameFinder,
  required Duration timeout,
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    final inEnabled = find.descendant(
      of: enabledListFinder,
      matching: appNameFinder,
    );
    if (inEnabled.evaluate().isNotEmpty) {
      return 'enabled';
    }

    final inInstalled = find.descendant(
      of: installedListFinder,
      matching: appNameFinder,
    );
    if (inInstalled.evaluate().isNotEmpty) {
      return 'installed';
    }

    await tester.pump(const Duration(milliseconds: 300));
  }
  return '';
}

Future<void> runSplitTunnelingAppsSmokeHarness(
  WidgetTester tester, {
  required String expectedAppName,
  bool enableIpCheck = false,
}) async {
  if (expectedAppName.trim().isEmpty) {
    fail('Apps split tunneling smoke requires a non-empty app name.');
  }

  if (enableIpCheck) {
    debugPrint(
      'ENABLE_IP_CHECK is set for apps split tunneling smoke; '
      'this scenario validates discovery and selection only.',
    );
  }

  final finders = VpnSmokeFinders();
  final vpnStateFinders = VpnStateFinders(textLabels: _vpnStateLabels);

  const splitSettingTileKey = Key('home.split_tunneling_setting');
  const splitScreenKey = Key('split_tunneling.screen');
  const splitToggleKey = Key('split_tunneling.enable_toggle');
  const appsTileKey = Key('split_tunneling.apps_tile');
  const appsScreenKey = Key('split_tunneling.apps.screen');
  const enabledListKey = Key('split_tunneling.apps.enabled_list');
  const installedListKey = Key('split_tunneling.apps.installed_list');

  final token = _keyToken(expectedAppName);
  final appNameKey = Key('split_tunneling.apps.name.$token');
  final addButtonKey = Key('split_tunneling.apps.add.$token');
  final removeButtonKey = Key('split_tunneling.apps.remove.$token');

  final appsTileFinder = find.byKey(appsTileKey);
  final enabledListFinder = find.byKey(enabledListKey);
  final installedListFinder = find.byKey(installedListKey);
  final appNameFinder = find.byKey(appNameKey);

  await prepareVpnStartsDisconnectedForSmoke(
    tester,
    finders: finders,
    vpnStateFinders: vpnStateFinders,
    scenario: 'apps split tunneling smoke',
  );

  await _tapFinder(
    tester,
    find.byKey(splitSettingTileKey),
    timeout: const Duration(seconds: 20),
    reason: 'Split tunneling setting tile was not found on home screen',
  );

  await WidgetWaitUtils.waitForFinder(
    tester,
    find.byKey(splitScreenKey),
    timeout: const Duration(seconds: 20),
    reason: 'Split tunneling screen did not open',
  );

  if (appsTileFinder.evaluate().isEmpty) {
    await _tapFinder(
      tester,
      find.byKey(splitToggleKey),
      timeout: const Duration(seconds: 20),
      reason: 'Split tunneling toggle was not found',
    );

    await WidgetWaitUtils.waitForFinder(
      tester,
      appsTileFinder,
      timeout: const Duration(seconds: 20),
      reason: 'Apps split tunneling tile did not appear after enabling',
    );
  }

  await _tapFinder(
    tester,
    appsTileFinder,
    timeout: const Duration(seconds: 20),
    reason: 'Apps split tunneling tile was not tappable',
  );

  await WidgetWaitUtils.waitForFinder(
    tester,
    find.byKey(appsScreenKey),
    timeout: const Duration(seconds: 20),
    reason: 'Apps split tunneling screen did not open',
  );

  await WidgetWaitUtils.waitForFinder(
    tester,
    enabledListFinder,
    timeout: const Duration(seconds: 20),
    reason: 'Enabled apps list was not visible',
  );
  await WidgetWaitUtils.waitForFinder(
    tester,
    installedListFinder,
    timeout: const Duration(seconds: 20),
    reason: 'Installed apps list was not visible',
  );

  var location = await _waitForAppLocation(
    tester: tester,
    enabledListFinder: enabledListFinder,
    installedListFinder: installedListFinder,
    appNameFinder: appNameFinder,
    timeout: const Duration(seconds: 90),
  );
  if (location.isEmpty) {
    fail(
      'Expected app "$expectedAppName" (token: $token) was not found in apps '
      'split tunneling lists. Visible keyed widgets: ${collectVisibleSmokeDebugKeys(tester)}',
    );
  }

  if (location == 'enabled') {
    final removeInEnabled = find.descendant(
      of: enabledListFinder,
      matching: find.byKey(removeButtonKey),
    );
    await _tapFinder(
      tester,
      removeInEnabled,
      timeout: const Duration(seconds: 20),
      reason:
          'Expected app "$expectedAppName" was enabled but remove action was not available',
    );

    location = await _waitForAppLocation(
      tester: tester,
      enabledListFinder: enabledListFinder,
      installedListFinder: installedListFinder,
      appNameFinder: appNameFinder,
      timeout: const Duration(seconds: 45),
    );
    if (location != 'installed') {
      fail(
        'Expected app "$expectedAppName" did not move back to installed list after remove.',
      );
    }
  }

  final addInInstalled = find.descendant(
    of: installedListFinder,
    matching: find.byKey(addButtonKey),
  );
  await _tapFinder(
    tester,
    addInInstalled,
    timeout: const Duration(seconds: 25),
    reason:
        'Add action for "$expectedAppName" was not available in installed list',
  );

  location = await _waitForAppLocation(
    tester: tester,
    enabledListFinder: enabledListFinder,
    installedListFinder: installedListFinder,
    appNameFinder: appNameFinder,
    timeout: const Duration(seconds: 45),
  );
  if (location != 'enabled') {
    fail(
      'Expected app "$expectedAppName" was not shown in enabled apps after add.',
    );
  }

  await _returnToHome(
    tester,
    homeScreen: finders.homeScreen,
    vpnToggle: finders.vpnToggle,
  );
}
