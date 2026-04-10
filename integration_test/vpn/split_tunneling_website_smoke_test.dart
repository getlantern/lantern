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

  testWidgets('Website split tunneling smoke', (tester) async {
    await app.main();
    await runSplitTunnelingWebsiteSmokeHarness(
      tester,
      enableIpCheck: _enableIpCheck,
    );
  });
}
