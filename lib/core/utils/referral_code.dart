import 'package:lantern/core/common/app_build_info.dart';

// Stripe promotion codes allow letters, digits, and hyphens, up to 500 characters.
const _maxReferralCodeLength = 500;
final _invalidReferralCodeCharacters = RegExp(r'[^A-Za-z0-9-]');

/// Normalizes a referral or promo code, or returns null for invalid input.
String? normalizeReferralCode(String value) {
  final code = value.trim();
  if (code.isEmpty ||
      code.length > _maxReferralCodeLength ||
      _invalidReferralCodeCharacters.hasMatch(code)) {
    return null;
  }
  return code.toUpperCase();
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
