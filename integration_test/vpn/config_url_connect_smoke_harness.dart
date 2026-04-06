import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/core/common/app_eum.dart';
import 'package:lantern/core/widgets/custom_app_bar.dart' as lantern_widgets;

import 'config_url_test_env.dart';
import '../utils/widget_wait_utils.dart';
import 'vpn_smoke_helpers.dart';

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

Future<void> _enterTextField(
  WidgetTester tester, {
  required Finder field,
  required String value,
  required String reason,
}) async {
  await WidgetWaitUtils.waitForFinder(
    tester,
    field,
    timeout: const Duration(seconds: 20),
    reason: reason,
  );
  await tester.ensureVisible(field.first);
  await tester.tap(field.first);
  await tester.pump(const Duration(milliseconds: 150));
  await tester.enterText(field.first, value);
  await tester.pump(const Duration(milliseconds: 150));
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

  try {
    await tester.pageBack();
    await tester.pump(const Duration(milliseconds: 250));
    return true;
  } catch (_) {
    return false;
  }
}

Future<void> _openServerSelectionFromHome(
  WidgetTester tester, {
  required Finder locationSettingTile,
  required Finder serverSelectionScreen,
}) async {
  await _tapFinder(
    tester,
    locationSettingTile,
    timeout: const Duration(seconds: 20),
    reason: 'Location setting tile not found on home screen',
  );

  await WidgetWaitUtils.waitForFinder(
    tester,
    serverSelectionScreen,
    timeout: const Duration(seconds: 30),
    reason: 'Server selection screen did not open from home',
  );
}

Future<void> _openJoinPrivateServerScreen(
  WidgetTester tester, {
  required Finder moreOptionsButton,
  required Finder joinPrivateServerTile,
  required Finder joinPrivateServerScreen,
}) async {
  await _tapFinder(
    tester,
    moreOptionsButton,
    timeout: const Duration(seconds: 20),
    reason: 'Server selection more options button not found',
  );

  await _tapFinder(
    tester,
    joinPrivateServerTile,
    timeout: const Duration(seconds: 20),
    reason: 'Join private server option not found in server options sheet',
  );

  await WidgetWaitUtils.waitForFinder(
    tester,
    joinPrivateServerScreen,
    timeout: const Duration(seconds: 20),
    reason: 'Join private server screen did not open',
  );
}

Future<void> _returnToServerSelection(
  WidgetTester tester, {
  required Finder serverSelectionScreen,
  required Finder joinPrivateServerScreen,
}) async {
  if (serverSelectionScreen.evaluate().isNotEmpty) {
    return;
  }

  final end = DateTime.now().add(const Duration(seconds: 20));
  while (DateTime.now().isBefore(end)) {
    if (serverSelectionScreen.evaluate().isNotEmpty) {
      return;
    }

    if (joinPrivateServerScreen.evaluate().isNotEmpty) {
      await _tryGoBack(tester);
      continue;
    }

    if (await _tryGoBack(tester)) {
      continue;
    }

    await tester.pump(const Duration(milliseconds: 250));
  }

  fail(
    'Failed to return to server selection after joining server. '
    'Visible keyed widgets: ${collectVisibleSmokeDebugKeys(tester)}',
  );
}

Future<void> _returnToHome(
  WidgetTester tester, {
  required Finder homeScreen,
}) async {
  if (homeScreen.evaluate().isNotEmpty) {
    return;
  }

  final end = DateTime.now().add(const Duration(seconds: 20));
  while (DateTime.now().isBefore(end)) {
    if (homeScreen.evaluate().isNotEmpty) {
      return;
    }

    if (await _tryGoBack(tester)) {
      continue;
    }

    await tester.pump(const Duration(milliseconds: 250));
  }

  fail(
    'Failed to return to home screen. '
    'Visible keyed widgets: ${collectVisibleSmokeDebugKeys(tester)}',
  );
}

Future<bool> _tapJoinedServerFromServerSelection(
  WidgetTester tester, {
  required Finder serverSelectionScreen,
  required Finder privateServersTab,
  required Finder joinedServerTileByKey,
  required Duration timeout,
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    if (serverSelectionScreen.evaluate().isEmpty) {
      return false;
    }

    final privateTab = privateServersTab.hitTestable();
    if (privateTab.evaluate().isNotEmpty) {
      await tester.tap(privateTab.first);
      await tester.pump(const Duration(milliseconds: 250));
    }

    final keyedTile = joinedServerTileByKey.hitTestable();
    if (keyedTile.evaluate().isNotEmpty) {
      await tester.tap(keyedTile.first);
      await tester.pump(const Duration(milliseconds: 250));
      return true;
    }

    await tester.pump(const Duration(milliseconds: 300));
  }

  return false;
}

Future<void> runConfigUrlConnectSmokeHarness(
  WidgetTester tester, {
  required String configUrl,
  required String configServerName,
  required bool skipCertVerification,
}) async {
  final urls = splitConfigUrls(configUrl);
  if (urls.length != 1) {
    fail(
      'Config URL UI smoke requires exactly one URL, but got ${urls.length}.',
    );
  }
  final url = urls.single;

  if (configServerName.trim().isEmpty) {
    fail(
      'JOIN_SERVER_CONFIG_SERVER_NAME must not be empty for config URL smoke test',
    );
  }
  if (!skipCertVerification) {
    fail(
      'JOIN_SERVER_CONFIG_SKIP_CERT_VERIFICATION=false is not supported in '
      'UI smoke because Join Server currently forces skip verification.',
    );
  }

  final finders = VpnSmokeFinders();
  final vpnStateFinders = VpnStateFinders();

  final homeLocationSetting = find.byKey(const Key('home.location_setting'));
  final serverSelectionScreen = find.byKey(
    const Key('server_selection.screen'),
  );
  final serverSelectionMoreOptions = find.byKey(
    const Key('server_selection.more_options'),
  );
  final serverSelectionJoinPrivateServer = find.byKey(
    const Key('server_selection.join_private_server'),
  );
  final serverSelectionPrivateTab = find.byKey(
    const Key('server_selection.private_servers_tab'),
  );
  final joinPrivateServerScreen = find.byKey(
    const Key('join_private_server.screen'),
  );
  final joinPrivateServerNameField = find.byKey(
    const Key('join_private_server.server_name'),
  );
  final joinPrivateServerUrlsField = find.byKey(
    const Key('join_private_server.urls'),
  );
  final joinPrivateServerSubmit = find.byKey(
    const Key('join_private_server.submit'),
  );
  final joinedServerTileByKey = find.byKey(
    Key('server_selection.private_server.$configServerName'),
  );

  await prepareVpnStartsDisconnectedForSmoke(
    tester,
    finders: finders,
    vpnStateFinders: vpnStateFinders,
    scenario: 'config URL smoke',
  );

  await _openServerSelectionFromHome(
    tester,
    locationSettingTile: homeLocationSetting,
    serverSelectionScreen: serverSelectionScreen,
  );

  await _openJoinPrivateServerScreen(
    tester,
    moreOptionsButton: serverSelectionMoreOptions,
    joinPrivateServerTile: serverSelectionJoinPrivateServer,
    joinPrivateServerScreen: joinPrivateServerScreen,
  );

  await _enterTextField(
    tester,
    field: joinPrivateServerNameField,
    value: configServerName,
    reason: 'Join private server name field was not available',
  );
  await _enterTextField(
    tester,
    field: joinPrivateServerUrlsField,
    value: url,
    reason: 'Join private server URL field was not available',
  );

  await _tapFinder(
    tester,
    joinPrivateServerSubmit,
    timeout: const Duration(seconds: 20),
    reason: 'Join private server submit button was not available',
  );

  await tester.pump(const Duration(milliseconds: 750));

  await _returnToServerSelection(
    tester,
    serverSelectionScreen: serverSelectionScreen,
    joinPrivateServerScreen: joinPrivateServerScreen,
  );

  var selected = await _tapJoinedServerFromServerSelection(
    tester,
    serverSelectionScreen: serverSelectionScreen,
    privateServersTab: serverSelectionPrivateTab,
    joinedServerTileByKey: joinedServerTileByKey,
    timeout: const Duration(seconds: 75),
  );

  if (!selected) {
    await _returnToHome(tester, homeScreen: finders.homeScreen);
    await _openServerSelectionFromHome(
      tester,
      locationSettingTile: homeLocationSetting,
      serverSelectionScreen: serverSelectionScreen,
    );

    selected = await _tapJoinedServerFromServerSelection(
      tester,
      serverSelectionScreen: serverSelectionScreen,
      privateServersTab: serverSelectionPrivateTab,
      joinedServerTileByKey: joinedServerTileByKey,
      timeout: const Duration(seconds: 45),
    );
  }

  if (!selected) {
    fail(
      'Joined private server "$configServerName" was not visible in server '
      'selection after submitting Join Server form. '
      '${buildVpnDebugSnapshot(tester, vpnStateFinders)}',
    );
  }

  await WidgetWaitUtils.waitForFinder(
    tester,
    finders.homeScreen,
    timeout: const Duration(seconds: 60),
    reason: 'Did not return to home screen after selecting joined server',
  );

  await vpnStateFinders.waitFor(
    tester,
    expected: const [VPNStatus.connected],
    timeout: const Duration(seconds: 60),
    reason: 'VPN did not reach connected state for joined server',
  );

  await _tapFinder(
    tester,
    finders.vpnToggle,
    timeout: const Duration(seconds: 15),
    reason: 'VPN toggle not available for disconnect after joined server test',
  );

  await vpnStateFinders.waitFor(
    tester,
    expected: const [VPNStatus.disconnected],
    timeout: const Duration(seconds: 45),
    reason: 'VPN did not return to disconnected state after config URL smoke',
  );
}
