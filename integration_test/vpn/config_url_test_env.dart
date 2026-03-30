import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const defaultConfigServerName = 'ci-config-url-smoke';

String requiredConfigUrls() {
  final urls = Platform.environment['JOIN_SERVER_CONFIG_URLS']?.trim() ?? '';
  if (urls.isNotEmpty) {
    return urls;
  }

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
    'JOIN_SERVER_CONFIG_URLS or JOIN_SERVER_CONFIG_URLS_FILE is not set for '
    'config URL smoke test',
  );
}

String configServerName() {
  final value =
      Platform.environment['JOIN_SERVER_CONFIG_SERVER_NAME']?.trim() ?? '';
  return value.isEmpty ? defaultConfigServerName : value;
}

bool skipCertVerification() {
  final raw = Platform.environment['JOIN_SERVER_CONFIG_SKIP_CERT_VERIFICATION']
      ?.trim()
      .toLowerCase();
  if (raw == null || raw.isEmpty) {
    return true;
  }
  return raw == '1' || raw == 'true' || raw == 'yes';
}
