import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const defaultConfigServerName = 'ci-config-url-smoke';
const _invisibleRunes = ['\uFEFF', '\u200B', '\u200C', '\u200D', '\u2060'];
const _supportedJoinServerSchemes = <String>{
  'ss',
  'shadowsocks',
  'trojan',
  'vmess',
  'vless',
  'hysteria',
  'hysteria2',
  'hy2',
};

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

String _stripInvisibleAndWrapperCharacters(String value) {
  var normalized = value.trim();
  for (final rune in _invisibleRunes) {
    normalized = normalized.replaceAll(rune, '');
  }
  if (normalized.length >= 2) {
    final startsWith = normalized[0];
    final endsWith = normalized[normalized.length - 1];
    final matchingWrapper =
        (startsWith == '"' && endsWith == '"') ||
        (startsWith == '\'' && endsWith == '\'') ||
        (startsWith == '`' && endsWith == '`') ||
        (startsWith == '<' && endsWith == '>');
    if (matchingWrapper) {
      normalized = normalized.substring(1, normalized.length - 1).trim();
    }
  }
  return normalized;
}

String _normalizeConfigUrlForProvider(String value) {
  // pluriconfig URL parser uses comma as a separator token, so commas inside
  // a single URL (for example ALPN lists) must be URL-encoded.
  return value.contains(',') ? value.replaceAll(',', '%2C') : value;
}

String requiredSingleConfigUrl() {
  final raw = _stripInvisibleAndWrapperCharacters(requiredConfigUrls());
  final urls = splitConfigUrls(raw);
  if (urls.length != 1) {
    fail(
      'Config URL smoke tests require exactly one URL, but received '
      '${urls.length}. Set JOIN_SERVER_CONFIG_URLS to a single URL value.',
    );
  }
  final normalized = _normalizeConfigUrlForProvider(urls.single.trim());
  final parsed = Uri.tryParse(normalized);
  final scheme = parsed?.scheme.toLowerCase() ?? '';
  if (scheme.isEmpty) {
    fail(
      'Config URL smoke test input is malformed (missing scheme). '
      'Use a direct URL like vless://..., trojan://..., vmess://..., or ss://...',
    );
  }
  if (!_supportedJoinServerSchemes.contains(scheme)) {
    fail(
      'Unsupported config URL scheme "$scheme" for smoke test. '
      'Supported: ${_supportedJoinServerSchemes.join(', ')}',
    );
  }
  return normalized;
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
