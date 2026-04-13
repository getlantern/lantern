import 'package:flutter_test/flutter_test.dart';

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
  testWidgets('Apps split tunneling smoke', (tester) async {
    await runSplitTunnelingAppsSmokeHarness(
      tester,
      expectedAppName: _splitTunnelSmokeAppName,
      enableIpCheck: _enableIpCheck,
    );
  });
}
