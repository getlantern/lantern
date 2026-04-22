import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/core/common/app_eum.dart';
import 'package:lantern/core/common/common.dart' show appRouter;
import 'package:lantern/core/utils/url_utils.dart';
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

const _splitTunnelDomainInput = 'api64.ipify.org';
const _splitTunnelEndpoint = 'https://api64.ipify.org';
const _regularEndpoint = 'https://icanhazip.com';
const _splitTunnelWindowsPublicPath =
    r'C:\Users\Public\Lantern\data\split-tunnel.json';

List<String> _splitTunnelRuleFileCandidates() {
  final candidates = <String>{_splitTunnelWindowsPublicPath};

  final programData = Platform.environment['ProgramData'];
  if (programData != null && programData.isNotEmpty) {
    candidates.add('$programData\\Lantern\\data\\split-tunnel.json');
  }

  final localAppData = Platform.environment['LOCALAPPDATA'];
  if (localAppData != null && localAppData.isNotEmpty) {
    candidates.add('$localAppData\\Lantern\\data\\split-tunnel.json');
  }

  return candidates.toList(growable: false);
}

Future<MapEntry<String, String>?> _readSplitTunnelConfigFromDisk() async {
  if (!Platform.isWindows) {
    return null;
  }

  for (final path in _splitTunnelRuleFileCandidates()) {
    final file = File(path);
    if (!await file.exists()) {
      continue;
    }
    try {
      final content = await file.readAsString();
      return MapEntry(path, content);
    } catch (error) {
      debugPrint('Split tunnel config read failed at "$path": $error');
    }
  }

  return null;
}

Future<void> _printSplitTunnelConfigSnapshot(String stage) async {
  final snapshot = await _readSplitTunnelConfigFromDisk();
  if (snapshot == null) {
    debugPrint(
      'Split tunnel config snapshot [$stage]: file not found. '
      'Checked: ${_splitTunnelRuleFileCandidates().join(', ')}',
    );
    return;
  }

  final content = snapshot.value.trim();
  debugPrint(
    'Split tunnel config snapshot [$stage] (${snapshot.key}): '
    '${content.isEmpty ? '(empty file)' : content}',
  );
}

bool _splitTunnelConfigContainsDomainSuffix(
  String content, {
  required String domain,
}) {
  try {
    final decoded = jsonDecode(content);
    if (decoded is! Map<String, dynamic>) {
      return false;
    }
  } catch (_) {
    return false;
  }

  final normalizedContent = content.toLowerCase();
  final normalizedDomain = domain.toLowerCase();
  return normalizedContent.contains('"domain_suffix"') &&
      normalizedContent.contains('"$normalizedDomain"');
}

Future<bool> _waitForDomainPersistenceInSplitTunnelConfig({
  required String domain,
  required Duration timeout,
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    final snapshot = await _readSplitTunnelConfigFromDisk();
    final content = snapshot?.value ?? '';
    if (_splitTunnelConfigContainsDomainSuffix(content, domain: domain)) {
      return true;
    }
    await Future<void>.delayed(const Duration(seconds: 1));
  }
  return false;
}

Future<String?> _fetchPublicIpOnce(String endpoint) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 6);
  try {
    final request = await client.getUrl(Uri.parse(endpoint));
    final response = await request.close().timeout(const Duration(seconds: 6));
    if (response.statusCode != HttpStatus.ok) {
      return null;
    }

    final body = await response
        .transform(const SystemEncoding().decoder)
        .join();
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
      debugPrint('Split tunnel IP check: fetched $reason');
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

Future<bool> _waitForPublicIpEquals({
  required String endpoint,
  required String expectedIp,
  required Duration timeout,
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    final current = await _fetchPublicIpOnce(endpoint);
    if (current != null && current.isNotEmpty && current == expectedIp) {
      return true;
    }
    await Future<void>.delayed(const Duration(seconds: 3));
  }
  return false;
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
    reason: 'VPN did not return to disconnected state after split tunnel smoke',
  );
}

Future<void> runSplitTunnelingWebsiteSmokeHarness(
  WidgetTester tester, {
  bool enableIpCheck = false,
}) async {
  final finders = VpnSmokeFinders();
  final vpnStateFinders = VpnStateFinders(textLabels: _vpnStateLabels);

  const splitSettingTileKey = Key('home.split_tunneling_setting');
  const splitScreenKey = Key('split_tunneling.screen');
  const splitToggleKey = Key('split_tunneling.enable_toggle');
  const websitesTileKey = Key('split_tunneling.websites_tile');
  const websiteScreenKey = Key('split_tunneling.website.screen');
  const websiteInputKey = Key('split_tunneling.website.input');
  const websiteAddButtonKey = Key('split_tunneling.website.add_button');

  Finder websiteRow(String domain) =>
      find.byKey(Key('split_tunneling.website.row.${domain.toLowerCase()}'));
  Finder removeWebsiteButton(String domain) =>
      find.byKey(Key('split_tunneling.website.remove.${domain.toLowerCase()}'));
  final normalizedSplitTunnelDomain = UrlUtils.extractDomain(
    _splitTunnelDomainInput,
  );

  await prepareVpnStartsDisconnectedForSmoke(
    tester,
    finders: finders,
    vpnStateFinders: vpnStateFinders,
    scenario: 'website split tunneling smoke',
  );

  String? baselineSplitDomainIp;
  String? baselineRegularDomainIp;
  if (enableIpCheck) {
    baselineSplitDomainIp = await _fetchPublicIpWithRetry(
      endpoint: _splitTunnelEndpoint,
      timeout: const Duration(seconds: 45),
      reason: 'split-domain baseline before connect',
    );
    baselineRegularDomainIp = await _fetchPublicIpWithRetry(
      endpoint: _regularEndpoint,
      timeout: const Duration(seconds: 45),
      reason: 'regular-domain baseline before connect',
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

  final websitesTileFinder = find.byKey(websitesTileKey);
  if (websitesTileFinder.evaluate().isEmpty) {
    await _tapFinder(
      tester,
      find.byKey(splitToggleKey),
      timeout: const Duration(seconds: 20),
      reason: 'Split tunneling toggle was not found',
    );

    await WidgetWaitUtils.waitForFinder(
      tester,
      websitesTileFinder,
      timeout: const Duration(seconds: 20),
      reason: 'Websites split tunneling tile did not appear after enabling',
    );
  }

  await _tapFinder(
    tester,
    websitesTileFinder,
    timeout: const Duration(seconds: 20),
    reason: 'Websites split tunneling tile was not tappable',
  );

  await WidgetWaitUtils.waitForFinder(
    tester,
    find.byKey(websiteScreenKey),
    timeout: const Duration(seconds: 20),
    reason: 'Website split tunneling screen did not open',
  );
  await _printSplitTunnelConfigSnapshot('before-domain-update');

  final existingRow = websiteRow(normalizedSplitTunnelDomain);
  if (existingRow.evaluate().isNotEmpty) {
    await _tapFinder(
      tester,
      removeWebsiteButton(normalizedSplitTunnelDomain),
      timeout: const Duration(seconds: 10),
      reason: 'Remove website button was not tappable',
    );
    await WidgetWaitUtils.waitForFinderToDisappear(
      tester,
      existingRow,
      timeout: const Duration(seconds: 20),
      reason: 'Existing website rule was not removed before re-adding',
    );
    await _printSplitTunnelConfigSnapshot('after-domain-remove');
  }

  await _enterTextField(
    tester,
    field: find.byKey(websiteInputKey),
    value: _splitTunnelDomainInput,
    reason: 'Website input field was not available',
  );
  await _tapFinder(
    tester,
    find.byKey(websiteAddButtonKey),
    timeout: const Duration(seconds: 20),
    reason: 'Website add button was not available',
  );
  await WidgetWaitUtils.waitForFinder(
    tester,
    websiteRow(normalizedSplitTunnelDomain),
    timeout: const Duration(seconds: 20),
    reason: 'New website split-tunnel rule was not visible after add',
  );
  await _printSplitTunnelConfigSnapshot('after-domain-add');

  final persisted = await _waitForDomainPersistenceInSplitTunnelConfig(
    domain: normalizedSplitTunnelDomain,
    timeout: const Duration(seconds: 20),
  );
  if (!persisted) {
    await _printSplitTunnelConfigSnapshot('persistence-timeout');
    fail(
      'Domain "$normalizedSplitTunnelDomain" was visible in UI but was not '
      'persisted to split-tunnel.json as domain_suffix within timeout.',
    );
  }
  await _printSplitTunnelConfigSnapshot('after-domain-persistence-check');

  await _returnToHome(
    tester,
    homeScreen: finders.homeScreen,
    vpnToggle: finders.vpnToggle,
  );
  await _printSplitTunnelConfigSnapshot('after-return-home');

  try {
    await _tapFinder(
      tester,
      finders.vpnToggle,
      timeout: const Duration(seconds: 20),
      reason: 'VPN toggle was not available for connect',
    );

    await vpnStateFinders.waitFor(
      tester,
      expected: const [VPNStatus.connected],
      timeout: const Duration(seconds: 45),
      reason: 'VPN did not reach connected state for split tunnel smoke',
    );

    if (enableIpCheck &&
        baselineSplitDomainIp != null &&
        baselineRegularDomainIp != null) {
      final regularDomainChanged = await _waitForPublicIpChangeFromBaseline(
        endpoint: _regularEndpoint,
        baselineIp: baselineRegularDomainIp,
        timeout: const Duration(seconds: 75),
      );
      if (!regularDomainChanged) {
        fail(
          'Public IP for regular endpoint did not change after VPN connect '
          '(baseline: $baselineRegularDomainIp)',
        );
      }

      final splitDomainBypassed = await _waitForPublicIpEquals(
        endpoint: _splitTunnelEndpoint,
        expectedIp: baselineSplitDomainIp,
        timeout: const Duration(seconds: 75),
      );
      if (!splitDomainBypassed) {
        fail(
          'Split-tunnel endpoint did not stay on baseline IP after VPN connect '
          '(expected: $baselineSplitDomainIp)',
        );
      }
    }
  } finally {
    await _disconnectVpnIfNeeded(
      tester,
      vpnToggle: finders.vpnToggle,
      vpnStateFinders: vpnStateFinders,
    );
  }
}
