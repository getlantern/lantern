import 'dart:io';

import 'package:integration_test/integration_test_driver.dart';

// Drive the installed, signed fixture without rebuilding its native components.
Future<void> main() => integrationDriver(
  // Allow the lifecycle test to finish and report before the driver times out.
  timeout: Duration(
    minutes: Platform.environment['VPN_LIFECYCLE_SMOKE'] == 'true' ? 50 : 20,
  ),
);
