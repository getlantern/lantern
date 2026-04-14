import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/core/common/app_eum.dart';
import 'package:lantern/core/common/common.dart' show appRouter;
import 'package:lantern/core/widgets/custom_app_bar.dart' as lantern_widgets;

import '../utils/widget_wait_utils.dart';
import 'split_tunnel_config_utils.dart';
import 'vpn_smoke_helpers.dart';

const _vpnStateLabels = <VPNStatus, String>{
  VPNStatus.connected: 'Connected',
  VPNStatus.disconnected: 'Disconnected',
  VPNStatus.connecting: 'Connecting',
  VPNStatus.disconnecting: 'Disconnecting',
  VPNStatus.missingPermission: 'MissingPermission',
  VPNStatus.error: 'Error',
};
const _defaultRouteBypassEndpoint = 'https://api64.ipify.org';
const _defaultRouteRegularEndpoint = 'https://icanhazip.com';

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

Finder _finderByKeyPrefix(String prefix) {
  return find.byWidgetPredicate((widget) {
    final key = widget.key;
    return key is ValueKey<String> && key.value.startsWith(prefix);
  }, description: 'widget key starts with "$prefix"');
}

Finder _appNameTextFinder(String expectedAppName) {
  final expected = expectedAppName.trim().toLowerCase();
  return find.byWidgetPredicate((widget) {
    if (widget is! Text) {
      return false;
    }
    final text = (widget.data ?? widget.textSpan?.toPlainText() ?? '')
        .trim()
        .toLowerCase();
    if (text.isEmpty || expected.isEmpty) {
      return false;
    }
    return text == expected ||
        text.contains(expected) ||
        expected.contains(text);
  }, description: 'text matching app name "$expectedAppName"');
}

String _collectListTextSnapshot(Finder listFinder, {int maxItems = 20}) {
  final textFinder = find.descendant(
    of: listFinder,
    matching: find.byType(Text),
  );
  final values = <String>[];
  for (final element in textFinder.evaluate()) {
    final widget = element.widget;
    if (widget is! Text) {
      continue;
    }
    final value = (widget.data ?? widget.textSpan?.toPlainText() ?? '').trim();
    if (value.isEmpty) {
      continue;
    }
    values.add(value);
    if (values.length >= maxItems) {
      break;
    }
  }

  if (values.isEmpty) {
    return '(none)';
  }
  return values.join(' | ');
}

bool _hasAnyAppMatchInList(Finder listFinder, List<Finder> appNameFinders) {
  for (final appNameFinder in appNameFinders) {
    final inList = find.descendant(of: listFinder, matching: appNameFinder);
    if (inList.evaluate().isNotEmpty) {
      return true;
    }
  }
  return false;
}

Finder _findActionButtonForAppInList({
  required Finder listFinder,
  required List<Finder> appNameFinders,
  required bool enabled,
  required Key fallbackActionKey,
}) {
  final actionPrefix = enabled
      ? 'split_tunneling.apps.remove.'
      : 'split_tunneling.apps.add.';
  final actionByPrefix = _finderByKeyPrefix(actionPrefix);

  for (final appNameFinder in appNameFinders) {
    final appInList = find.descendant(of: listFinder, matching: appNameFinder);
    if (appInList.evaluate().isEmpty) {
      continue;
    }

    final rowFinder = find.ancestor(
      of: appInList.first,
      matching: _finderByKeyPrefix('split_tunneling.apps.row.'),
    );
    if (rowFinder.evaluate().isEmpty) {
      continue;
    }

    final actionInRow = find.descendant(
      of: rowFinder.first,
      matching: actionByPrefix,
    );
    if (actionInRow.evaluate().isNotEmpty) {
      return actionInRow.first;
    }
  }

  return find.descendant(
    of: listFinder,
    matching: find.byKey(fallbackActionKey),
  );
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
  required List<Finder> appNameFinders,
  required Duration timeout,
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    if (_hasAnyAppMatchInList(enabledListFinder, appNameFinders)) {
      return 'enabled';
    }

    if (_hasAnyAppMatchInList(installedListFinder, appNameFinders)) {
      return 'installed';
    }

    await tester.pump(const Duration(milliseconds: 300));
  }
  return '';
}

Future<String?> _fetchPublicIpOnce(String endpoint) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 6);
  try {
    final request = await client.getUrl(Uri.parse(endpoint));
    final response = await request.close().timeout(const Duration(seconds: 6));
    if (response.statusCode != HttpStatus.ok) {
      return null;
    }

    final body = await response.transform(const Utf8Decoder()).join();
    final ip = body.trim();
    if (ip.isNotEmpty && InternetAddress.tryParse(ip) != null) {
      return ip;
    }
  } catch (_) {
    return null;
  } finally {
    client.close(force: true);
  }
  return null;
}

Future<String> _fetchPublicIpWithRetry({
  required String endpoint,
  required Duration timeout,
  required String reason,
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    final ip = await _fetchPublicIpOnce(endpoint);
    if (ip != null && ip.isNotEmpty) {
      debugPrint('Apps split tunnel route check: fetched $reason');
      return ip;
    }
    await Future<void>.delayed(const Duration(seconds: 2));
  }
  fail('Failed to fetch public IP: $reason');
}

Future<bool> _waitForPublicIpChangeFromBaseline({
  required String endpoint,
  required String baselineIp,
  required Duration timeout,
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    final current = await _fetchPublicIpOnce(endpoint);
    if (current != null && current.isNotEmpty && current != baselineIp) {
      return true;
    }
    await Future<void>.delayed(const Duration(seconds: 3));
  }
  return false;
}

String? _extractIpFromText(String text) {
  for (final line in const LineSplitter().convert(
    text.replaceAll('\r', '\n'),
  )) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) {
      continue;
    }
    final sanitized = trimmed.replaceAll(RegExp(r'[^0-9A-Fa-f\.:]'), '');
    if (sanitized.isEmpty) {
      continue;
    }
    final parsed = InternetAddress.tryParse(sanitized);
    if (parsed != null) {
      return parsed.address;
    }
  }
  return null;
}

String? _resolveBrowserExecutablePath(String configuredPath) {
  final candidates = <String>[];
  if (configuredPath.trim().isNotEmpty) {
    candidates.add(configuredPath.trim());
  }

  final programFilesX86 = Platform.environment['ProgramFiles(x86)'];
  if (programFilesX86 != null && programFilesX86.isNotEmpty) {
    candidates.add(
      '$programFilesX86\\Microsoft\\Edge\\Application\\msedge.exe',
    );
    candidates.add('$programFilesX86\\Google\\Chrome\\Application\\chrome.exe');
  }

  final programFiles = Platform.environment['ProgramFiles'];
  if (programFiles != null && programFiles.isNotEmpty) {
    candidates.add('$programFiles\\Microsoft\\Edge\\Application\\msedge.exe');
    candidates.add('$programFiles\\Google\\Chrome\\Application\\chrome.exe');
  }

  final localAppData = Platform.environment['LOCALAPPDATA'];
  if (localAppData != null && localAppData.isNotEmpty) {
    candidates.add('$localAppData\\Google\\Chrome\\Application\\chrome.exe');
  }

  for (final path in candidates) {
    if (path.isEmpty) {
      continue;
    }
    if (File(path).existsSync()) {
      return path;
    }
  }
  return null;
}

Future<String?> _fetchPublicIpViaBrowserProcessOnce({
  required String browserPath,
  required String endpoint,
  required String userDataDirPath,
}) async {
  final args = <String>[
    '--headless=new',
    '--disable-gpu',
    '--no-first-run',
    '--no-default-browser-check',
    '--disable-background-networking',
    '--disable-extensions',
    '--user-data-dir=$userDataDirPath',
    '--dump-dom',
    endpoint,
  ];

  try {
    final result = await Process.run(
      browserPath,
      args,
    ).timeout(const Duration(seconds: 25));

    final output = '${result.stdout}\n${result.stderr}';
    final ip = _extractIpFromText(output);
    if (result.exitCode == 0 && ip != null && ip.isNotEmpty) {
      return ip;
    }

    debugPrint(
      'Apps split tunnel route check browser command failed '
      '(exit=${result.exitCode}, ip=$ip)',
    );
  } catch (error) {
    debugPrint('Apps split tunnel route check browser command failed: $error');
  }
  return null;
}

Future<String> _fetchPublicIpViaBrowserWithRetry({
  required String browserPath,
  required String endpoint,
  required String userDataDirPath,
  required Duration timeout,
  required String reason,
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    final ip = await _fetchPublicIpViaBrowserProcessOnce(
      browserPath: browserPath,
      endpoint: endpoint,
      userDataDirPath: userDataDirPath,
    );
    if (ip != null && ip.isNotEmpty) {
      debugPrint('Apps split tunnel route check: fetched $reason');
      return ip;
    }
    await Future<void>.delayed(const Duration(seconds: 3));
  }
  fail('Failed to fetch public IP via browser process: $reason');
}

Future<bool> _waitForBrowserPublicIpEquals({
  required String browserPath,
  required String endpoint,
  required String expectedIp,
  required String userDataDirPath,
  required Duration timeout,
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    final current = await _fetchPublicIpViaBrowserProcessOnce(
      browserPath: browserPath,
      endpoint: endpoint,
      userDataDirPath: userDataDirPath,
    );
    if (current != null && current.isNotEmpty && current == expectedIp) {
      return true;
    }
    await Future<void>.delayed(const Duration(seconds: 3));
  }
  return false;
}

Future<void> _disconnectVpnIfNeeded(
  WidgetTester tester, {
  required Finder vpnToggle,
  required VpnStateFinders vpnStateFinders,
}) async {
  final currentState = vpnStateFinders.current();
  if (currentState != VPNStatus.connected &&
      currentState != VPNStatus.connecting) {
    return;
  }

  await _tapFinder(
    tester,
    vpnToggle,
    timeout: const Duration(seconds: 20),
    reason: 'VPN toggle not available for disconnect',
  );

  await vpnStateFinders.waitFor(
    tester,
    expected: const [VPNStatus.disconnected],
    timeout: const Duration(seconds: 45),
    reason: 'VPN did not return to disconnected state after apps smoke',
  );
}

Future<void> runSplitTunnelingAppsSmokeHarness(
  WidgetTester tester, {
  required String expectedAppName,
  String expectedAppExecutableHint = '',
  bool enableIpCheck = false,
  bool validateRouteBypass = false,
  String routeBypassEndpoint = _defaultRouteBypassEndpoint,
  String routeRegularEndpoint = _defaultRouteRegularEndpoint,
  String routeBrowserExecutablePath = '',
}) async {
  if (expectedAppName.trim().isEmpty) {
    fail('Apps split tunneling smoke requires a non-empty app name.');
  }

  if (enableIpCheck && !validateRouteBypass) {
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
  final normalizedExecutableHint = expectedAppExecutableHint.trim();
  String? resolvedBrowserPath;
  Directory? browserUserDataDir;
  String? baselineRegularIp;
  String? baselineBypassIp;

  final appsTileFinder = find.byKey(appsTileKey);
  final enabledListFinder = find.byKey(enabledListKey);
  final installedListFinder = find.byKey(installedListKey);
  final appNameFinders = <Finder>[
    find.byKey(appNameKey),
    _appNameTextFinder(expectedAppName),
  ];

  debugPrint(
    'Apps split tunneling smoke: preparing home state for app "$expectedAppName" (token=$token)',
  );
  await prepareVpnStartsDisconnectedForSmoke(
    tester,
    finders: finders,
    vpnStateFinders: vpnStateFinders,
    scenario: 'apps split tunneling smoke',
  );

  if (validateRouteBypass) {
    if (!Platform.isWindows) {
      fail(
        'Apps split tunnel route validation currently supports Windows only.',
      );
    }
    if (normalizedExecutableHint.isEmpty) {
      fail(
        'Apps split tunnel route validation requires a non-empty '
        'SPLIT_TUNNEL_SMOKE_APP_EXECUTABLE_HINT.',
      );
    }

    baselineRegularIp = await _fetchPublicIpWithRetry(
      endpoint: routeRegularEndpoint,
      timeout: const Duration(seconds: 45),
      reason: 'regular endpoint baseline before connect',
    );

    resolvedBrowserPath = _resolveBrowserExecutablePath(
      routeBrowserExecutablePath,
    );
    if (resolvedBrowserPath == null) {
      fail(
        'Apps split tunnel route validation did not find a browser executable. '
        'Pass SPLIT_TUNNEL_ROUTE_BROWSER_PATH or install Edge/Chrome.',
      );
    }

    browserUserDataDir = await Directory.systemTemp.createTemp(
      'lantern-split-smoke-browser-',
    );
    baselineBypassIp = await _fetchPublicIpViaBrowserWithRetry(
      browserPath: resolvedBrowserPath,
      endpoint: routeBypassEndpoint,
      userDataDirPath: browserUserDataDir.path,
      timeout: const Duration(seconds: 60),
      reason: 'browser bypass endpoint baseline before connect',
    );
  }

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
  await printSplitTunnelConfigSnapshot('apps-before-selection');

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
    appNameFinders: appNameFinders,
    timeout: const Duration(seconds: 120),
  );
  if (location.isEmpty) {
    final enabledSnapshot = _collectListTextSnapshot(enabledListFinder);
    final installedSnapshot = _collectListTextSnapshot(installedListFinder);
    fail(
      'Expected app "$expectedAppName" (token: $token) was not found in apps '
      'split tunneling lists. '
      'Enabled list text: $enabledSnapshot. Installed list text: $installedSnapshot. '
      'Visible keyed widgets: ${collectVisibleSmokeDebugKeys(tester)}',
    );
  }

  if (location == 'enabled') {
    final removeInEnabled = _findActionButtonForAppInList(
      listFinder: enabledListFinder,
      appNameFinders: appNameFinders,
      enabled: true,
      fallbackActionKey: removeButtonKey,
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
      appNameFinders: appNameFinders,
      timeout: const Duration(seconds: 45),
    );
    if (location != 'installed') {
      fail(
        'Expected app "$expectedAppName" did not move back to installed list after remove.',
      );
    }
  }

  final addInInstalled = _findActionButtonForAppInList(
    listFinder: installedListFinder,
    appNameFinders: appNameFinders,
    enabled: false,
    fallbackActionKey: addButtonKey,
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
    appNameFinders: appNameFinders,
    timeout: const Duration(seconds: 75),
  );
  if (location != 'enabled') {
    final enabledSnapshot = _collectListTextSnapshot(enabledListFinder);
    final installedSnapshot = _collectListTextSnapshot(installedListFinder);
    fail(
      'Expected app "$expectedAppName" was not shown in enabled apps after add. '
      'Enabled list text: $enabledSnapshot. Installed list text: $installedSnapshot.',
    );
  }
  await printSplitTunnelConfigSnapshot('apps-after-add');

  if (normalizedExecutableHint.isNotEmpty) {
    final persisted = await waitForProcessPathPersistenceInSplitTunnelConfig(
      processPathFragment: normalizedExecutableHint,
      timeout: const Duration(seconds: 20),
    );
    if (!persisted) {
      await printSplitTunnelConfigSnapshot('apps-persistence-timeout');
      fail(
        'App "$expectedAppName" was enabled in UI but split-tunnel config '
        'did not persist a process_path entry containing '
        '"$normalizedExecutableHint".',
      );
    }
  } else {
    debugPrint(
      'Apps split tunneling smoke skipped process_path persistence check '
      '(SPLIT_TUNNEL_SMOKE_APP_EXECUTABLE_HINT not set).',
    );
  }

  await _returnToHome(
    tester,
    homeScreen: finders.homeScreen,
    vpnToggle: finders.vpnToggle,
  );

  if (!validateRouteBypass) {
    return;
  }

  try {
    await _tapFinder(
      tester,
      finders.vpnToggle,
      timeout: const Duration(seconds: 20),
      reason: 'VPN toggle was not available for apps route smoke connect',
    );

    await vpnStateFinders.waitFor(
      tester,
      expected: const [VPNStatus.connected],
      timeout: const Duration(seconds: 45),
      reason: 'VPN did not reach connected state for apps route smoke',
    );

    final regularDomainChanged = await _waitForPublicIpChangeFromBaseline(
      endpoint: routeRegularEndpoint,
      baselineIp: baselineRegularIp!,
      timeout: const Duration(seconds: 75),
    );
    if (!regularDomainChanged) {
      fail(
        'Public IP for regular endpoint did not change after VPN connect '
        '(baseline: $baselineRegularIp)',
      );
    }

    final bypassStayed = await _waitForBrowserPublicIpEquals(
      browserPath: resolvedBrowserPath!,
      endpoint: routeBypassEndpoint,
      expectedIp: baselineBypassIp!,
      userDataDirPath: browserUserDataDir!.path,
      timeout: const Duration(seconds: 90),
    );
    if (!bypassStayed) {
      fail(
        'App process did not stay on baseline IP for bypass endpoint after VPN connect '
        '(expected: $baselineBypassIp)',
      );
    }
  } finally {
    await _disconnectVpnIfNeeded(
      tester,
      vpnToggle: finders.vpnToggle,
      vpnStateFinders: vpnStateFinders,
    );

    if (browserUserDataDir != null) {
      try {
        if (await browserUserDataDir.exists()) {
          await browserUserDataDir.delete(recursive: true);
        }
      } catch (_) {}
    }
  }
}
