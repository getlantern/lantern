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
const _splitTunnelSmokeAppExecutableHint = String.fromEnvironment(
  'SPLIT_TUNNEL_SMOKE_APP_EXECUTABLE_HINT',
  defaultValue: '',
);
const _splitTunnelRouteCheck = bool.fromEnvironment(
  'SPLIT_TUNNEL_ROUTE_CHECK',
  defaultValue: false,
);
const _splitTunnelRouteBrowserPath = String.fromEnvironment(
  'SPLIT_TUNNEL_ROUTE_BROWSER_PATH',
  defaultValue: '',
);
const _splitTunnelRouteBypassEndpoint = String.fromEnvironment(
  'SPLIT_TUNNEL_ROUTE_BYPASS_ENDPOINT',
  defaultValue: 'https://api64.ipify.org',
);
const _splitTunnelRouteRegularEndpoint = String.fromEnvironment(
  'SPLIT_TUNNEL_ROUTE_REGULAR_ENDPOINT',
  defaultValue: 'https://icanhazip.com',
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final testName = _splitTunnelRouteCheck
      ? 'Apps split tunneling route smoke'
      : 'Apps split tunneling smoke';

  testWidgets(testName, (tester) async {
    await app.main();
    await runSplitTunnelingAppsSmokeHarness(
      tester,
      expectedAppName: _splitTunnelSmokeAppName,
      expectedAppExecutableHint: _splitTunnelSmokeAppExecutableHint,
      enableIpCheck: _enableIpCheck,
      validateRouteBypass: _splitTunnelRouteCheck,
      routeBypassEndpoint: _splitTunnelRouteBypassEndpoint,
      routeRegularEndpoint: _splitTunnelRouteRegularEndpoint,
      routeBrowserExecutablePath: _splitTunnelRouteBrowserPath,
    );
  });
}
