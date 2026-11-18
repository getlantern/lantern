import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lantern/core/common/app_eum.dart';
import 'package:lantern/core/localization/i18n.dart';
import 'package:lantern/main.dart' as app;
import 'package:path/path.dart' as p;

import '../utils/app_robot.dart';
import '../utils/widget_wait_utils.dart';
import 'connect_smoke_harness.dart';
import 'vpn_smoke_helpers.dart';

const _serviceName = 'LanternSvc';

const _vpnStateLabels = <VPNStatus, String>{
  VPNStatus.connected: 'Connected',
  VPNStatus.disconnected: 'Disconnected',
  VPNStatus.connecting: 'Connecting',
  VPNStatus.disconnecting: 'Disconnecting',
  VPNStatus.missingPermission: 'MissingPermission',
  VPNStatus.error: 'Error',
};

/// Runs sc.exe and returns its output, failing the test on a non-zero exit
/// unless [allowFailure] is set.
Future<String> _sc(List<String> args, {bool allowFailure = false}) async {
  final result = await Process.run('sc.exe', args);
  final output = '${result.stdout}${result.stderr}';
  debugPrint('sc.exe ${args.join(' ')} -> ${result.exitCode}\n$output');
  if (result.exitCode != 0 && !allowFailure) {
    fail('sc.exe ${args.join(' ')} failed (${result.exitCode}): $output');
  }
  return output;
}

/// Leaves LanternSvc as the reports describe it: stopped and set not to
/// start, so nothing brings lanternd back on its own.
Future<void> _breakService() async {
  await _sc(['config', _serviceName, 'start=', 'disabled']);
  await _sc(['stop', _serviceName], allowFailure: true);
  final deadline = DateTime.now().add(const Duration(seconds: 60));
  while (DateTime.now().isBefore(deadline)) {
    if ((await _sc(['query', _serviceName])).contains('STOPPED')) return;
    await Future<void>.delayed(const Duration(seconds: 1));
  }
  fail('$_serviceName did not stop');
}

Future<void> _captureScreenshot(WidgetTester tester, String name) async {
  const directory = String.fromEnvironment(
    'SERVICE_REPAIR_SCREENSHOT_DIR',
    defaultValue: 'build/windows-service-repair-smoke',
  );
  await tester.pump(const Duration(milliseconds: 300));
  await AppRobot(tester).captureScreenshot(name, outputDirectory: directory);
  expect(
    await File(p.join(directory, '$name.png')).exists(),
    isTrue,
    reason: 'Windows service repair screenshot was not captured',
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Windows offers to repair a stopped service and reconnects', (
    tester,
  ) async {
    expect(Platform.isWindows, isTrue);
    await app.main();

    final finders = VpnSmokeFinders();
    final vpnStateFinders = VpnStateFinders(textLabels: _vpnStateLabels);
    await prepareVpnStartsDisconnectedForSmoke(
      tester,
      finders: finders,
      vpnStateFinders: vpnStateFinders,
      scenario: 'service repair smoke',
    );

    await _breakService();

    await tester.tap(finders.vpnToggle);
    final dialogTitle = find.text('lantern_service_unavailable_title'.i18n);
    await WidgetWaitUtils.waitForFinder(
      tester,
      dialogTitle,
      timeout: const Duration(seconds: 60),
      reason: 'Connect did not offer to repair the stopped service',
    );
    await _captureScreenshot(tester, 'service-repair-dialog');

    await tester.tap(find.text('repair'.i18n));
    await tester.pump(const Duration(milliseconds: 200));
    try {
      await vpnStateFinders.waitFor(
        tester,
        expected: const [VPNStatus.connected],
        timeout: const Duration(seconds: 120),
        reason: 'VPN did not connect after repairing the service',
      );
      expect(dialogTitle, findsNothing);
      expect(
        find.text('lantern_service_repair_failed'.i18n),
        findsNothing,
        reason: 'The repair reported a failure',
      );
      await _captureScreenshot(tester, 'service-repaired-connected');
      expect(
        await _sc(['qc', _serviceName]),
        contains('AUTO_START'),
        reason: 'The repair did not set the service to start automatically',
      );
    } finally {
      await disconnectVpnForSmoke(
        tester,
        vpnToggle: finders.vpnToggle,
        vpnStateFinders: vpnStateFinders,
      );
    }
  });
}
