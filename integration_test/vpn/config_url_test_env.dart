import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const defaultConfigServerName = 'ci-config-url-smoke';
final _urlSeparatorPattern = RegExp(r'[\s,]+');
const _invisibleCharacters = <String>{
  '\uFEFF', // byte order mark (BOM)
  '\u200B', // zero-width space
  '\u200C', // zero-width non-joiner
  '\u200D', // zero-width joiner
  '\u2060', // word joiner
};
const _wrapperPairs = <String, String>{
  '"': '"',
  '\'': '\'',
  '`': '`',
  '<': '>',
};
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
      .split(_urlSeparatorPattern)
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

String _stripInvisibleCharacters(String value) {
  var normalized = value.trim();
  for (final character in _invisibleCharacters) {
    normalized = normalized.replaceAll(character, '');
  }
  return normalized;
}

String _stripOptionalWrappingCharacters(String value) {
  if (value.length < 2) {
    return value;
  }
  for (final entry in _wrapperPairs.entries) {
    if (value.startsWith(entry.key) && value.endsWith(entry.value)) {
      return value.substring(1, value.length - 1).trim();
    }
  }
  return value;
}

String _sanitizeConfigUrlInput(String value) {
  final withoutInvisible = _stripInvisibleCharacters(value);
  return _stripOptionalWrappingCharacters(withoutInvisible);
}

String _normalizeConfigUrlForProvider(String value) {
  // pluriconfig URL parser uses comma as a separator token, so commas inside
  // a single URL (for example ALPN lists) must be URL-encoded.
  return value.contains(',') ? value.replaceAll(',', '%2C') : value;
}

String _validateAndReturnNormalizedSingleConfigUrl(String value) {
  final normalized = _normalizeConfigUrlForProvider(value.trim());
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

String requiredSingleConfigUrl() {
  final raw = _sanitizeConfigUrlInput(requiredConfigUrls());
  final urls = splitConfigUrls(raw);
  if (urls.length != 1) {
    fail(
      'Config URL smoke tests require exactly one URL, but received '
      '${urls.length}. Set JOIN_SERVER_CONFIG_URLS to a single URL value.',
    );
  }
  return _validateAndReturnNormalizedSingleConfigUrl(urls.single);
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
