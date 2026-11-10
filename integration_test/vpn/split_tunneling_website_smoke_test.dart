import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lantern/main.dart' as app;

import 'split_tunneling_website_smoke_harness.dart';

const _enableIpCheck = bool.fromEnvironment(
  'ENABLE_IP_CHECK',
  defaultValue: false,
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  registerSplitTunnelingWebsiteSmokeTests();
}

/// Also run by the Android e2e suite, without the IP checks: Lantern is off
/// its own VPN there, so SplitTunnelCaptureTest checks routing instead.
void registerSplitTunnelingWebsiteSmokeTests() {
  testWidgets(
    'Website split tunneling modes, cancellation and wildcards',
    (tester) async {
      await app.main();
      await runSplitTunnelingWebsiteSmokeHarness(
        tester,
        enableIpCheck: _enableIpCheck,
      );
    },
    timeout: const Timeout(Duration(minutes: 12)),
  );
}
