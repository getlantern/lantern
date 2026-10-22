import 'package:lantern/core/common/app_build_info.dart';

// Bound referral and affiliate input before passing it to native processing.
const _maxReferralCodeLength = 200;
final _invalidReferralCodeCharacters = RegExp(r'[^A-Za-z0-9-]');

/// Trims a referral or affiliate code without changing case; null if invalid.
String? normalizeReferralCode(String value) {
  final code = value.trim();
  if (code.isEmpty ||
      code.length > _maxReferralCodeLength ||
      _invalidReferralCodeCharacters.hasMatch(code)) {
    return null;
  }
  return code;
}

/// Reads one code from a supported affiliate link's path or query.
String? affiliateCodeFromUri(Uri uri) {
  final isWebLink =
      uri.scheme == 'https' &&
      (uri.host == 'lantern.io' || uri.host == 'www.lantern.io') &&
      uri.port == 443;
  final isAppLink =
      AppBuildInfo.isAppAuthUri(uri) && uri.host == 'affiliate' && !uri.hasPort;
  if ((!isWebLink && !isAppLink) ||
      uri.userInfo.isNotEmpty ||
      uri.hasFragment) {
    return null;
  }

  try {
    final segments = uri.pathSegments.toList();
    if (isWebLink) {
      if (segments.isEmpty || segments.removeAt(0) != 'affiliate') return null;
    }
    if (segments.isNotEmpty && segments.last.isEmpty) segments.removeLast();
    if (segments.length > 1) return null;

    final queryCodes = uri.queryParametersAll['code'];
    if (queryCodes != null && queryCodes.length != 1) return null;
    if (segments.isNotEmpty && queryCodes != null) return null;
    final code = segments.isNotEmpty ? segments.single : queryCodes?.single;
    // Spaces may come from pasting a code, but don't belong in a link value.
    if (code == null || code != code.trim()) return null;
    return normalizeReferralCode(code);
  } on FormatException {
    return null;
  }
}
