import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/core/common/app_eum.dart';
import 'package:lantern/core/common/common.dart' show appRouter;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lantern/core/common/app_buttons.dart';
import 'package:lantern/core/localization/i18n.dart';
import 'package:lantern/core/models/split_tunnel_state.dart';
import 'package:lantern/core/services/injection_container.dart';
import 'package:lantern/features/split_tunneling/provider/split_tunnel_notifier.dart';
import 'package:lantern/lantern/lantern_service.dart';
import 'package:lantern/core/widgets/custom_app_bar.dart' as lantern_widgets;

import '../utils/widget_wait_utils.dart';
import 'split_tunneling_smoke_helpers.dart';
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
  final states = VpnStateFinders(textLabels: _vpnStateLabels);
  final service = sl<LanternService>();
  await prepareVpnStartsDisconnectedForSmoke(
    tester,
    finders: finders,
    vpnStateFinders: states,
    scenario: 'split tunneling modes and websites',
  );
  final container = ProviderScope.containerOf(
    tester.element(finders.homeScreen),
  );
  Future<SplitTunnelState> readState() async => requireSplitTunnelResult(
    await service.getSplitTunnelState(),
    'Read authoritative split-tunnel state',
  );
  final original = await readState();
  expect(
    original.supported,
    isTrue,
    reason: 'The smoke requires the new daemon state API',
  );
  final wasSmart = requireSplitTunnelResult(
    await service.isSmartRoutingEnabled(),
    'Read routing mode',
  );
  addTearDown(() async {
    requireSplitTunnelResult(
      await service.stopVPN(),
      'Disconnect after split-tunnel smoke',
    );
    await restoreSplitTunnelSnapshot(service, original);
    requireSplitTunnelResult(
      await service.setRoutingMode(wasSmart),
      'Restore routing mode',
    );
  });

  Future<void> openSplit() async {
    await _returnToHome(
      tester,
      homeScreen: finders.homeScreen,
      vpnToggle: finders.vpnToggle,
    );
    await _tapFinder(
      tester,
      find.byKey(const Key('home.split_tunneling_setting')),
      timeout: const Duration(seconds: 20),
      reason: 'Open split tunneling',
    );
    await WidgetWaitUtils.waitForFinder(
      tester,
      find.byKey(const Key('split_tunneling.screen')),
      timeout: const Duration(seconds: 20),
      reason: 'Split tunneling screen did not open',
    );
  }

  Future<void> openWebsites() async {
    await openSplit();
    await _tapFinder(
      tester,
      find.byKey(const Key('split_tunneling.websites_tile')),
      timeout: const Duration(seconds: 20),
      reason: 'Open website selections',
    );
    await WidgetWaitUtils.waitForFinder(
      tester,
      find.byKey(const Key('split_tunneling.website.screen')),
      timeout: const Duration(seconds: 20),
      reason: 'Website screen did not open',
    );
  }

  Future<void> switchMode(
    SplitTunnelPolicy policy, {
    bool cancel = false,
  }) async {
    await openSplit();
    final before = await readState();
    expect(before.policy, isNot(policy));
    await _tapFinder(
      tester,
      find.byKey(Key('split_tunneling.mode.${policy.wireValue}')),
      timeout: const Duration(seconds: 20),
      reason: 'Choose split-tunnel mode',
    );
    await _tapFinder(
      tester,
      find.byKey(Key('split_tunneling.mode.${cancel ? 'cancel' : 'confirm'}')),
      timeout: const Duration(seconds: 20),
      reason: 'Confirm or cancel mode switch',
    );
    final deadline = DateTime.now().add(const Duration(seconds: 30));
    while (true) {
      await tester.pump(const Duration(milliseconds: 200));
      final snapshot = await readState();
      if (cancel) {
        expect(snapshot.policy, before.policy);
        expect(snapshot.filters, before.filters);
        return;
      }
      if (snapshot.policy == policy) {
        expect(snapshot.appCount, 0);
        expect(snapshot.websiteCount, 0);
        return;
      }
      if (DateTime.now().isAfter(deadline)) {
        fail('Mode switch did not reach the daemon');
      }
    }
  }

  Future<void> addWebsite(
    String input,
    String display,
    String canonical,
  ) async {
    await _enterTextField(
      tester,
      field: find.byKey(const Key('split_tunneling.website.input')),
      value: input,
      reason: 'Website input was not available',
    );
    await _tapFinder(
      tester,
      find.byKey(const Key('split_tunneling.website.add_button')),
      timeout: const Duration(seconds: 20),
      reason: 'Website Add was not available',
    );
    final row = find.byKey(Key('split_tunneling.website.row.$display'));
    final deadline = DateTime.now().add(const Duration(seconds: 20));
    while (row.evaluate().isEmpty) {
      await tester.pump(const Duration(milliseconds: 200));
      final dialog = find.ancestor(
        of: find.text('bypass_website_first_time_title'.i18n),
        matching: find.byType(AlertDialog),
      );
      if (dialog.evaluate().isNotEmpty) {
        await _tapFinder(
          tester,
          find.descendant(
            of: dialog,
            matching: find.widgetWithText(PrimaryButton, 'add'.i18n),
          ),
          timeout: const Duration(seconds: 10),
          reason: 'Confirm first website bypass',
        );
      }
      if (DateTime.now().isAfter(deadline)) {
        fail('Website $display was not shown after adding it');
      }
    }
    expect(
      (await readState()).selectors(SplitTunnelFilterType.domainSuffix),
      contains(canonical),
    );
    if (Platform.isWindows) {
      expect(
        await waitForSplitTunnelRule(
          field: 'domain_suffix',
          value: canonical,
          present: true,
          timeout: const Duration(seconds: 20),
        ),
        isTrue,
        reason: 'Website was not durably saved',
      );
    }
  }

  Future<void> expectRouting({
    required bool selectedUsesVPN,
    required bool otherUsesVPN,
    required String selectedBaseline,
    required String otherBaseline,
  }) async {
    for (final check in [
      (_splitTunnelEndpoint, selectedBaseline, selectedUsesVPN),
      (_regularEndpoint, otherBaseline, otherUsesVPN),
    ]) {
      final matches = check.$3
          ? await _waitForPublicIpChangeFromBaseline(
              endpoint: check.$1,
              baselineIp: check.$2,
              timeout: const Duration(seconds: 75),
            )
          : await _waitForPublicIpEquals(
              endpoint: check.$1,
              expectedIp: check.$2,
              timeout: const Duration(seconds: 75),
            );
      expect(
        matches,
        isTrue,
        reason:
            '${check.$1} did not ${check.$3 ? 'use the VPN' : 'remain direct'}',
      );
    }
  }

  requireSplitTunnelResult(
    await service.setRoutingMode(false),
    'Use full tunnel for routing assertions',
  );
  requireSplitTunnelResult(
    await service.switchSplitTunnelPolicy('include'),
    'Reset fixture selections',
  );
  requireSplitTunnelResult(
    await service.switchSplitTunnelPolicy('exclude'),
    'Start in Bypass',
  );
  requireSplitTunnelResult(
    await service.setSplitTunnelingEnabled(false),
    'Start split tunneling disabled',
  );
  expect(await container.read(splitTunnelProvider.notifier).refresh(), isNull);
  await openSplit();
  await _tapFinder(
    tester,
    find.byKey(const Key('split_tunneling.enable_toggle')),
    timeout: const Duration(seconds: 20),
    reason: 'Enable split tunneling',
  );
  await openWebsites();
  await addWebsite(
    'https://API64.IPIFY.ORG./test?query=1',
    _splitTunnelDomainInput,
    _splitTunnelDomainInput,
  );
  await switchMode(SplitTunnelPolicy.includeOnly, cancel: true);

  final selectedBaseline = enableIpCheck
      ? await _fetchPublicIpWithRetry(
          endpoint: _splitTunnelEndpoint,
          timeout: const Duration(seconds: 45),
          reason: 'selected host direct baseline',
        )
      : '';
  final otherBaseline = enableIpCheck
      ? await _fetchPublicIpWithRetry(
          endpoint: _regularEndpoint,
          timeout: const Duration(seconds: 45),
          reason: 'other host direct baseline',
        )
      : '';
  await _returnToHome(
    tester,
    homeScreen: finders.homeScreen,
    vpnToggle: finders.vpnToggle,
  );
  await _tapFinder(
    tester,
    finders.vpnToggle,
    timeout: const Duration(seconds: 20),
    reason: 'Connect VPN',
  );
  await states.waitFor(
    tester,
    expected: const [VPNStatus.connected],
    timeout: const Duration(seconds: 60),
    reason: 'VPN did not connect',
  );
  if (enableIpCheck) {
    await expectRouting(
      selectedUsesVPN: false,
      otherUsesVPN: true,
      selectedBaseline: selectedBaseline,
      otherBaseline: otherBaseline,
    );
  }

  await switchMode(SplitTunnelPolicy.includeOnly);
  if (enableIpCheck) {
    await expectRouting(
      selectedUsesVPN: false,
      otherUsesVPN: false,
      selectedBaseline: selectedBaseline,
      otherBaseline: otherBaseline,
    );
  }
  await openWebsites();
  await addWebsite('*.IPIFY.ORG.', '*.ipify.org', '.ipify.org');
  await openWebsites();
  expect(
    find.byKey(const Key('split_tunneling.website.row.*.ipify.org')),
    findsOneWidget,
  );
  if (enableIpCheck) {
    await expectRouting(
      selectedUsesVPN: true,
      otherUsesVPN: false,
      selectedBaseline: selectedBaseline,
      otherBaseline: otherBaseline,
    );
  }
  await switchMode(SplitTunnelPolicy.bypass, cancel: true);
  await switchMode(SplitTunnelPolicy.bypass);
  if (enableIpCheck) {
    await expectRouting(
      selectedUsesVPN: true,
      otherUsesVPN: true,
      selectedBaseline: selectedBaseline,
      otherBaseline: otherBaseline,
    );
  }
  await _returnToHome(
    tester,
    homeScreen: finders.homeScreen,
    vpnToggle: finders.vpnToggle,
  );
  await _disconnectVpnIfNeeded(
    tester,
    vpnToggle: finders.vpnToggle,
    vpnStateFinders: states,
  );
}
