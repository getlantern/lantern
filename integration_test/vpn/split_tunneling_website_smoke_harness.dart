import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/core/common/app_eum.dart';
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

const _splitTunnelDomain = 'api64.ipify.org';
const _splitTunnelEndpoint = 'https://api64.ipify.org';
const _regularEndpoint = 'https://api.ipify.org';

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
}) async {
  if (homeScreen.evaluate().isNotEmpty) {
    return;
  }

  final end = DateTime.now().add(const Duration(seconds: 25));
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

  await prepareVpnStartsDisconnectedForSmoke(
    tester,
    finders: finders,
    vpnStateFinders: vpnStateFinders,
    scenario: 'website split tunneling smoke',
  );

  String? baselineSplitDomainIp;
  if (enableIpCheck) {
    baselineSplitDomainIp = await _fetchPublicIpWithRetry(
      endpoint: _splitTunnelEndpoint,
      timeout: const Duration(seconds: 45),
      reason: 'split-domain baseline before connect',
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

  final existingRow = websiteRow(_splitTunnelDomain);
  if (existingRow.evaluate().isNotEmpty) {
    await _tapFinder(
      tester,
      removeWebsiteButton(_splitTunnelDomain),
      timeout: const Duration(seconds: 10),
      reason: 'Remove website button was not tappable',
    );
    await WidgetWaitUtils.waitForFinderToDisappear(
      tester,
      existingRow,
      timeout: const Duration(seconds: 20),
      reason: 'Existing website rule was not removed before re-adding',
    );
  }

  await _enterTextField(
    tester,
    field: find.byKey(websiteInputKey),
    value: _splitTunnelDomain,
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
    websiteRow(_splitTunnelDomain),
    timeout: const Duration(seconds: 20),
    reason: 'New website split-tunnel rule was not visible after add',
  );

  await _returnToHome(tester, homeScreen: finders.homeScreen);

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

    if (enableIpCheck && baselineSplitDomainIp != null) {
      final regularDomainChanged = await _waitForPublicIpChangeFromBaseline(
        endpoint: _regularEndpoint,
        baselineIp: baselineSplitDomainIp,
        timeout: const Duration(seconds: 75),
      );
      if (!regularDomainChanged) {
        fail(
          'Public IP for regular endpoint did not change after VPN connect '
          '(baseline: $baselineSplitDomainIp)',
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
