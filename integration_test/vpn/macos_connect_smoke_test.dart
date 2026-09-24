import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lantern/core/common/app_eum.dart';
import 'package:lantern/core/models/macos_extension_state.dart';
import 'package:lantern/features/macos_extension/provider/macos_extension_notifier.dart';
import 'package:lantern/main.dart' as app;

import '../utils/widget_wait_utils.dart';
import 'connect_smoke_harness.dart';
import 'vpn_smoke_helpers.dart';

const _enableIpCheck = bool.fromEnvironment(
  'ENABLE_IP_CHECK',
  defaultValue: false,
);
const _lifecycleSmoke = bool.fromEnvironment('VPN_LIFECYCLE_SMOKE');

const _extensionBlockingStatuses = <SystemExtensionStatus>{
  SystemExtensionStatus.requiresApproval,
  SystemExtensionStatus.requiresReboot,
  SystemExtensionStatus.timedOut,
  SystemExtensionStatus.error,
};

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'macOS VPN connect/disconnect smoke',
    (tester) async {
      await app.main();
      await _requireSystemExtensionReady(tester);
      if (_lifecycleSmoke) {
        await _runLifecycleSmoke(tester);
      } else {
        await runConnectSmokeHarness(
          tester,
          enableIpCheck: _enableIpCheck,
          requireTrafficAfterConnect: true,
        );
      }
    },
    timeout: const Timeout(Duration(minutes: 15)),
  );
}

Future<void> _runLifecycleSmoke(WidgetTester tester) async {
  final directory = Directory('/Users/Shared/Lantern/E2E');
  await directory.create(recursive: true);
  final request = File('${directory.path}/vpn-smoke-request.json');
  final result = File('${directory.path}/vpn-smoke-result.json');

  Future<void> clearRequest() async {
    for (final file in [request, result]) {
      if (await file.exists()) await file.delete();
    }
  }

  Future<String> setRequest(String action) async {
    await clearRequest();
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final temporary = File('${request.path}.tmp');
    await temporary.writeAsString(jsonEncode({'id': id, 'action': action}));
    await temporary.rename(request.path);
    return id;
  }

  Future<Map<String, dynamic>> waitForResult(String id, String stage) async {
    final deadline = DateTime.now().add(const Duration(seconds: 60));
    while (DateTime.now().isBefore(deadline)) {
      if (await result.exists()) {
        final receipt =
            jsonDecode(await result.readAsString()) as Map<String, dynamic>;
        if (receipt['id'] == id && receipt['stage'] == stage) {
          debugPrint('macOS VPN smoke: $receipt');
          return receipt;
        }
      }
      await tester.pump(const Duration(milliseconds: 200));
    }
    fail('The installed extension did not report $stage for attempt $id');
  }

  await clearRequest();
  try {
    // Keep the app alive across cycles so reconnects exercise the same client.
    for (var cycle = 0; cycle < 3; cycle++) {
      debugPrint('macOS VPN smoke: normal cycle ${cycle + 1}/3');
      await runConnectSmokeHarness(
        tester,
        enableIpCheck: true,
        requireIpRestored: true,
      );
    }

    final baseline = await fetchPublicIpForSmoke(
      timeout: const Duration(seconds: 40),
      reason: 'before injected failure',
    );
    final failedAttempt = await setRequest('failAfterSettings');
    await tester.tap(VpnSmokeFinders().vpnToggle);
    await tester.pump(const Duration(milliseconds: 200));
    await waitForResult(failedAttempt, 'failed-after-settings');
    await VpnStateFinders().waitFor(
      tester,
      expected: const [VPNStatus.disconnected],
      timeout: const Duration(seconds: 45),
      reason: 'The failed tunnel did not disconnect',
    );
    await expectPublicIpRestored(baseline);

    for (var cycle = 0; cycle < 3; cycle++) {
      debugPrint('macOS VPN smoke: fallback cycle ${cycle + 1}/3');
      final id = await setRequest('fallback');
      await runConnectSmokeHarness(
        tester,
        enableIpCheck: true,
        requireIpRestored: true,
        afterConnect: () async {
          final receipt = await waitForResult(id, 'fallback');
          expect(receipt['interface'], matches(r'^utun\d+$'));
          expect(receipt['addresses'], isNotEmpty);
        },
      );
    }
  } finally {
    await clearRequest();
    await disconnectVpnForSmoke(
      tester,
      vpnToggle: VpnSmokeFinders().vpnToggle,
      vpnStateFinders: VpnStateFinders(),
    );
  }
}

Future<void> _requireSystemExtensionReady(WidgetTester tester) async {
  final finders = VpnSmokeFinders();
  final extensionScreen = find.byKey(const Key('macos_extension.screen'));

  await WidgetWaitUtils.waitForAnyFinder(
    tester,
    [extensionScreen, finders.homeScreen, finders.onboardingScreen],
    timeout: const Duration(seconds: 90),
    reason: 'Lantern did not reach a visible app screen after launch',
  );

  final container = _providerContainerForVisibleApp(tester, [
    extensionScreen,
    finders.homeScreen,
    finders.onboardingScreen,
  ]);
  var state = container.read(macosExtensionProvider);
  final end = DateTime.now().add(const Duration(seconds: 45));

  while (DateTime.now().isBefore(end)) {
    if (state.isReady) {
      debugPrint('macOS smoke: system extension ready (${state.status.name})');
      return;
    }

    if (_extensionBlockingStatuses.contains(state.status)) {
      fail(_systemExtensionDebugMessage(tester, state));
    }

    await tester.pump(const Duration(milliseconds: 300));
    state = container.read(macosExtensionProvider);
  }

  fail(_systemExtensionDebugMessage(tester, state));
}

ProviderContainer _providerContainerForVisibleApp(
  WidgetTester tester,
  List<Finder> finders,
) {
  for (final finder in finders) {
    final elements = finder.evaluate();
    if (elements.isNotEmpty) {
      return ProviderScope.containerOf(elements.first, listen: false);
    }
  }

  fail('No visible app widget found for provider lookup');
}

String _systemExtensionDebugMessage(
  WidgetTester tester,
  MacOSExtensionState state,
) {
  final statusKey = Key('macos_extension.status.${state.status.name}');
  final statusKeyVisible = find.byKey(statusKey).evaluate().isNotEmpty;
  final details = state.message == null ? '' : ' Details: ${state.message}.';

  return 'macOS system extension was not ready before connect: '
      '${state.status.name}.$details '
      'Status key visible: $statusKeyVisible. '
      'Visible keyed widgets: ${collectVisibleSmokeDebugKeys(tester)}';
}
