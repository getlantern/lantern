import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lantern/main.dart' as app;

import 'config_url_api_smoke_harness.dart';
import 'config_url_test_env.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Linux config URL API connect/disconnect smoke', (tester) async {
    await app.main();
    await runConfigUrlApiConnectSmokeHarness(
      tester,
      configUrl: requiredSingleConfigUrl(),
      configServerName: configServerName(),
      skipCertVerification: skipCertVerification(),
    );
  });
}
