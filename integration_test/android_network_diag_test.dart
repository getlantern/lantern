import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lantern/main.dart' as app;

import 'utils/network_diagnostics.dart';
import 'vpn/android_connect_smoke_harness.dart';

/// Diagnostic Firebase Test Lab target for backend calls that stop working on
/// physical devices partway through the Android suite. Each round records
/// network diagnostics before and after the VPN scenarios, to separate a
/// network that blocks the app's routes from one the VPN leaves broken.
/// Build it with ANDROID_INTEGRATION_TARGET; the checks only log NETDIAG lines.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  for (var round = 1; round <= 3; round++) {
    registerNetworkDiagnostics('round $round before VPN');

    testWidgets('round $round: VPN scenarios', (tester) async {
      await app.main();
      await runAndroidConnectSmoke(tester);
      await app.main();
      await runAndroidRoutingModeSmoke(tester);
    });

    registerNetworkDiagnostics('round $round after VPN');
  }
}
