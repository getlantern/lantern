import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lantern/main.dart' as app;

import 'config_url_connect_smoke_harness.dart';

const _defaultServerName = 'ci-config-url-smoke';

String _requiredConfigUrls() {
  final urls = Platform.environment['JOIN_SERVER_CONFIG_URLS']?.trim() ?? '';
  if (urls.isEmpty) {
    final filePath =
        Platform.environment['JOIN_SERVER_CONFIG_URLS_FILE']?.trim() ?? '';
    if (filePath.isNotEmpty) {
      final file = File(filePath);
      if (file.existsSync()) {
        final fileUrls = file.readAsStringSync().trim();
        if (fileUrls.isNotEmpty) {
          return fileUrls;
        }
      }
    }
    fail(
      'JOIN_SERVER_CONFIG_URLS or JOIN_SERVER_CONFIG_URLS_FILE is not set for config URL smoke test',
    );
  }
  return urls;
}

String _configServerName() {
  final value =
      Platform.environment['JOIN_SERVER_CONFIG_SERVER_NAME']?.trim() ?? '';
  return value.isEmpty ? _defaultServerName : value;
}

bool _skipCertVerification() {
  final raw = Platform.environment['JOIN_SERVER_CONFIG_SKIP_CERT_VERIFICATION']
      ?.trim()
      .toLowerCase();
  if (raw == null || raw.isEmpty) {
    return true;
  }
  return raw == '1' || raw == 'true' || raw == 'yes';
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Windows config URL connect/disconnect smoke', (tester) async {
    app.main();
    await runConfigUrlConnectSmokeHarness(
      tester,
      configUrls: _requiredConfigUrls(),
      configServerName: _configServerName(),
      skipCertVerification: _skipCertVerification(),
    );
  });
}
