import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lantern/main.dart' as app;

import 'utils/app_robot.dart';
import 'vpn/android_connect_smoke_harness.dart';

// Device and ABI arguments are documented in docs/android-arm32-validation.md.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('native and Flutter startup reaches a usable home', (
    tester,
  ) async {
    await app.main();
    final robot = AppRobot(tester);
    await robot.waitForHomeReady();
    await robot.captureScreenshot('architecture-startup');
  });

  testWidgets('VPN changes public IP and restores it after disconnect', (
    tester,
  ) async {
    await app.main();
    await runAndroidConnectSmoke(tester, enableIpCheck: true);
  });

  testWidgets('VPN reconnects after disconnect on the selected ABI', (
    tester,
  ) async {
    await app.main();
    await runAndroidReconnectSmoke(tester);
  });
}
