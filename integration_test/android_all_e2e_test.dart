import 'package:integration_test/integration_test.dart';

import 'report_issue/report_issue_smoke_test.dart';
import 'vpn/android_vpn_smoke_test.dart';

/// Aggregator entrypoint for all Android end-to-end tests. This is the single
/// `-Ptarget` Firebase Test Lab builds so every suite runs in one instrumentation
/// session (one build, one device slot). Each suite lives in its own file and
/// exposes a `registerXxxTests()` function; add a suite by importing it and
/// calling its register function below.
///
/// All cases share one app process, so each scenario must establish its own
/// baseline rather than assume clean state (see VpnRobot.ensureDisconnected).
///
/// System dialogs (VPN consent, notifications) are pre-granted on-device by the
/// androidTest wrapper. For local runs use `make android-integration-test`.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  registerVpnSmokeTests();
  registerReportIssueSmokeTests();
}
