import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/core/common/app_eum.dart';
import 'package:lantern/core/services/injection_container.dart';
import 'package:lantern/lantern/lantern_service.dart';

import 'config_url_test_env.dart';
import 'vpn_smoke_helpers.dart';

Never _failWithFailure(
  String message,
  dynamic failure,
  WidgetTester tester,
  VpnStateFinders vpnStateFinders,
) {
  fail('$message: $failure. ${buildVpnDebugSnapshot(tester, vpnStateFinders)}');
}

Future<void> runConfigUrlApiConnectSmokeHarness(
  WidgetTester tester, {
  required String configUrl,
  required String configServerName,
  required bool skipCertVerification,
}) async {
  final urls = splitConfigUrls(configUrl);
  if (urls.length != 1) {
    fail(
      'Config URL API smoke requires exactly one URL, but got '
      '${urls.length}.',
    );
  }
  final url = urls.single;
  if (configServerName.trim().isEmpty) {
    fail(
      'JOIN_SERVER_CONFIG_SERVER_NAME must not be empty for config URL API smoke test',
    );
  }

  final lantern = sl<LanternService>();
  final finders = VpnSmokeFinders();
  final vpnStateFinders = VpnStateFinders();

  await waitForHomeReadyForVpnSmoke(tester, finders: finders);

  var state = await resolveInitialStableVpnStateForSmoke(
    tester,
    finders: finders,
    vpnStateFinders: vpnStateFinders,
  );

  if (state == VPNStatus.error) {
    fail(
      'VPN reported error before config URL API smoke. '
      '${buildVpnDebugSnapshot(tester, vpnStateFinders)}',
    );
  }
  if (state == VPNStatus.missingPermission) {
    fail(
      'VPN reported missing permission before config URL API smoke. '
      '${buildVpnDebugSnapshot(tester, vpnStateFinders)}',
    );
  }

  if (state == VPNStatus.connected) {
    final stop = await lantern.stopVPN();
    stop.fold(
      (failure) => _failWithFailure(
        'Failed to stop VPN before config URL API smoke',
        failure,
        tester,
        vpnStateFinders,
      ),
      (_) {},
    );

    state = await vpnStateFinders.waitFor(
      tester,
      expected: const [VPNStatus.disconnected],
      timeout: const Duration(seconds: 45),
      reason:
          'VPN did not reach disconnected state before config URL API smoke',
    );
  }

  if (state != VPNStatus.disconnected) {
    fail(
      'Expected disconnected state before config URL API smoke, got '
      '${state.name}. ${buildVpnDebugSnapshot(tester, vpnStateFinders)}',
    );
  }

  final addServerResult = await lantern.addServerBasedOnURLs(
    urls: url,
    skipCertVerification: skipCertVerification,
    serverName: configServerName,
  );
  addServerResult.fold(
    (failure) => _failWithFailure(
      'Failed to add server from config URL(s)',
      failure,
      tester,
      vpnStateFinders,
    ),
    (_) {},
  );

  final connectResult = await lantern.connectToServer(
    ServerLocationType.privateServer.name,
    configServerName,
  );
  connectResult.fold(
    (failure) => _failWithFailure(
      'Failed to connect to config URL server "$configServerName"',
      failure,
      tester,
      vpnStateFinders,
    ),
    (_) {},
  );

  await vpnStateFinders.waitFor(
    tester,
    expected: const [VPNStatus.connected],
    timeout: const Duration(seconds: 60),
    reason: 'VPN did not reach connected state for config URL API smoke',
  );

  final stop = await lantern.stopVPN();
  stop.fold(
    (failure) => _failWithFailure(
      'Failed to stop VPN after config URL API smoke',
      failure,
      tester,
      vpnStateFinders,
    ),
    (_) {},
  );

  await vpnStateFinders.waitFor(
    tester,
    expected: const [VPNStatus.disconnected],
    timeout: const Duration(seconds: 45),
    reason:
        'VPN did not return to disconnected state after config URL API smoke',
  );
}
