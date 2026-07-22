import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:integration_test/integration_test.dart';
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

const _extensionBlockingStatuses = <SystemExtensionStatus>{
  SystemExtensionStatus.requiresApproval,
  SystemExtensionStatus.requiresReboot,
  SystemExtensionStatus.timedOut,
  SystemExtensionStatus.error,
};

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('macOS VPN connect/disconnect smoke', (tester) async {
    await app.main(const []);
    await _requireSystemExtensionReady(tester);
    await runConnectSmokeHarness(
      tester,
      enableIpCheck: _enableIpCheck,
      requireTrafficAfterConnect: true,
    );
  });
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
