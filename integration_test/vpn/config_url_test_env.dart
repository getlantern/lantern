import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const defaultConfigServerName = 'ci-config-url-smoke';

List<String> splitConfigUrls(String urls) {
  return urls
      .split(RegExp(r'[\s,]+'))
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toList();
}

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

String requiredSingleConfigUrl() {
  final urls = splitConfigUrls(requiredConfigUrls());
  if (urls.length != 1) {
    fail(
      'Config URL smoke tests require exactly one URL, but received '
      '${urls.length}. Set JOIN_SERVER_CONFIG_URLS to a single URL value.',
    );
  }
  return urls.single;
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
