import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lantern/main.dart' as app;

import 'android_connect_smoke_harness.dart';

/// Android VPN smoke suite — the single entrypoint Firebase Test Lab builds
/// (`-Ptarget=…/android_vpn_smoke_test.dart`). Add new VPN scenarios as
/// `testWidgets` inside [registerVpnSmokeTests]; they all run in one FTL
/// instrumentation session. Each scenario must establish its own baseline
/// (e.g. VpnRobot.ensureDisconnected) since they share one app process.
///
/// The VpnService consent + notification dialogs never appear: the androidTest
/// wrapper (android/app/src/androidTest) pre-grants them before launch. For a
/// manual local run, prefer `make android-integration-test`.
const _enableIpCheck = bool.fromEnvironment(
  'ENABLE_IP_CHECK',
  defaultValue: false,
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  registerVpnSmokeTests();
}

/// Registers the VPN smoke scenarios. Exposed separately so a future
/// cross-feature aggregator entrypoint can pull these in alongside other
/// suites without duplicating the list.
void registerVpnSmokeTests() {
  testWidgets('VPN connect/disconnect smoke', (tester) async {
    await app.main();
    await runAndroidConnectSmoke(tester, enableIpCheck: _enableIpCheck);
  });

  testWidgets('VPN reconnects cleanly after disconnect', (tester) async {
    await app.main();
    await runAndroidReconnectSmoke(tester);
  });

  testWidgets('VPN IP changes across routing modes (smart <-> full)', (
    tester,
  ) async {
    await app.main();
    await runAndroidRoutingModeIpChangeSmoke(tester);
  });
}
