import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lantern/main.dart' as app;

import 'connect_smoke_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Windows VPN connect/disconnect smoke', (tester) async {
    app.main();
    await runConnectSmokeHarness(tester);
  });
}
