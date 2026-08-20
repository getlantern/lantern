import 'package:integration_test/integration_test_driver.dart';

// The auto-update smoke uses flutter drive so it can control the installed,
// signed profile fixture and leave it running for the native updater handoff.
Future<void> main() => integrationDriver();
