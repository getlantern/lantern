import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lantern/main.dart' as app;

import 'split_tunneling_apps_smoke_harness.dart';

const _enableIpCheck = bool.fromEnvironment(
  'ENABLE_IP_CHECK',
  defaultValue: false,
);
const _splitTunnelSmokeAppName = String.fromEnvironment(
  'SPLIT_TUNNEL_SMOKE_APP_NAME',
  defaultValue: 'Claude',
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Apps split tunneling smoke', (tester) async {
    await app.main();
    await runSplitTunnelingAppsSmokeHarness(
      tester,
      expectedAppName: _splitTunnelSmokeAppName,
      enableIpCheck: _enableIpCheck,
    );
  });
}
